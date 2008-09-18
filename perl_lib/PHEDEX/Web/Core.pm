package PHEDEX::Web::Core;

=pod
=head1 NAME

PHEDEX::Web::Core - fetch, format, and return PhEDEx data

=head1 DESCRIPTION

This is the core module of the PhEDEx Data Service, a framework to
serve PhEDEx data in multiple formats for machine consumption.

=head2 URL Format

Calls to the PhEDEx data service should be made using the following URL format:

C<http://host.cern.ch/phedex/datasvc/FORMAT/INSTANCE/CALL?OPTIONS>

 FORMAT    the desired output format (e.g. xml, json, or perl)
 INSTANCE  the PhEDEx database instance from which to fetch the data
           (e.g. prod, debug, dev)
 CALL      the API call to make (see below)
 OPTIONS   the options to the CALL, in standard query string format

=head2 Output

Each response will have the following data in its "top level"
attributes.  With the XML format, these attributes appear in the
top-level "phedex" element.

 request_timestamp  unix timestamp, time of request
 request_date       human-readable time of request
 request_call       name of API call
 instance           PhEDEx DB instance
 call_time          time it took to serve call
 request_url        the full URL of the request

=head2 Errors

When possible, errors are returned in the format requested by the
user.  However, if the user's format could not be determined by the
datasvc, the error will be returned as XML.

Errors contain one element, <error>, which contains a text message of
the problem.

C<http://host.cern.ch/phedex/datasvc/xml/prod/foobar>

   <error>
   API call 'foobar' is not defined.  Check the URL
   </error>

=head2 Multi-Value filters

Filters with multiple values follow some common rules for all calls,
unless otherwise specified:

 * by default the multiple-value filters form an "or" statement
 * by specifying another option, 'op=name:and', the filters will form an "and" statement
 * filter values beginning with '!' look for negated matches
 * filter values may contain the wildcard character '*'

examples:

 ...?node=A&node=B&node=C
    node matches A, B, or C; but not D, E, or F
 ...?node=foo*&op=node:and&node=!foobar
    node matches 'foobaz', 'foochump', but not 'foobar'

=cut

use warnings;
use strict;

use base 'PHEDEX::Web::SQL';
use PHEDEX::Web::Util;
use PHEDEX::Web::Cache;
use PHEDEX::Core::Loader;
use PHEDEX::Core::Timing;
use PHEDEX::Web::Format;
use HTML::Entities; # for encoding XML

# TODO: When call-specific SQL is removed from PHEDEX::Web::SQL and
# something more modular is used, stop using these libraries and just
# use our base SQL class, PHEDEX::Web::SQL
use PHEDEX::Core::SQL;
#use PHEDEX::Web::SQL; # already used as a base class above...

our (%params);
%params = ( VERSION => undef,
            DBCONFIG => undef,
	    INSTANCE => undef,
	    REQUEST_URL => undef,
            REMOTE_HOST => undef,
            USER_AGENT => undef,
	    REQUEST_TIME => undef,
	    SECMOD => undef,
	    DEBUG => 0,
	    CACHE_CONFIG => undef,
	    );

# A map of API calls to data sources
our $call_data = { };

# Data source parameters
our $data_sources = { };

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = ref($proto) ? $class->SUPER::new(@_) : {};
    
    my %args = (@_);
    map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
    } keys %params; 

    $self->{REQUEST_TIME} ||= &mytimeofday();

    bless $self, $class;

    # Set up database connection
    my $t1 = &mytimeofday();
    $self->connectToDatabase(0);
    my $t2 = &mytimeofday();
    warn "db connection time ", sprintf('%.6f s', $t2-$t1), "\n" if $self->{DEBUG};

    $self->{CACHE} = PHEDEX::Web::Cache->new( %{$self->{CACHE_CONFIG}} );

    return $self;
}

sub AUTOLOAD
{
    my $self = shift;
    my $attr = our $AUTOLOAD;
    $attr =~ s/.*:://;
    if ( exists($params{$attr}) )
    {
	$self->{$attr} = shift if @_;
	return $self->{$attr};
    }
    my $parent = "SUPER::" . $attr;
    $self->$parent(@_);
}

sub DESTROY
{
}

sub call
{
    my ($self, $call, %args) = @_;
    no strict 'refs';

    # check the format argument then remove it
    my $format = $args{format};
    if (!grep $_ eq $format, qw( xml json perl )) {
        &PHEDEX::Web::Format::error(*STDOUT, 'xml', "Return format requested is unknown or undefined");
	return;
    }
    delete $args{format};

    if (!$call) {
	&PHEDEX::Web::Format::error(*STDOUT, $format, "No API call provided.  Check the URL");
	return;
    }

    my ($t1,$t2,$loader,$module);
    $loader = PHEDEX::Core::Loader->new( NAMESPACE => 'PHEDEX::Web::API' );
    $module = $loader->Load($call);

    $t1 = &mytimeofday();
    &process_args(\%args);

    my $obj = $self->getData($call, %args);
    my $stdout = '';
    if ( ! $obj )
    {
      eval {
        open (local *STDOUT,'>',\$stdout); # capture STDOUT of $call
        my $invoke = $module . '::invoke';
        $obj = $invoke->($self, %args);
#	$obj = { $call => $obj };
      };
      if ($@) {
          &PHEDEX::Web::Format::error(*STDOUT, $format, "Error when making call '$call':  $@");
	  return;
      }
      $t2 = &mytimeofday();
      warn "api call '$call' complete in ", sprintf('%.6f s',$t2-$t1), "\n" if $self->{DEBUG};
      my $duration = 0;
      $duration = $module->duration() if $module->can('duration');
      $self->{CACHE}->set( $call, \%args, $obj, $duration ); # unless $args{nocache};
    }

#   wrap the object in a 'phedex' element with useful metadata
    $obj->{stdout}->{'$t'} = $stdout if $stdout;
    $obj->{instance} = $self->{INSTANCE};
    $obj->{request_version} = $self->{VERSION};
    $obj->{request_url} = $self->{REQUEST_URL};
    $obj->{request_call} = $call;
    $obj->{request_timestamp} = $self->{REQUEST_TIME};
    $obj->{request_date} = &formatTime($self->{REQUEST_TIME}, 'stamp');
    $obj->{call_time} = sprintf('%.5f', $t2 - $t1);
    $obj = { phedex => $obj };

    $t1 = &mytimeofday();
    &PHEDEX::Web::Format::output(*STDOUT, $format, $obj);
    $t2 = &mytimeofday();
    warn "api call '$call' delivered in ", sprintf('%.6f s', $t2-$t1), "\n" if $self->{DEBUG};

    return $obj;
}

# Cache controls

sub refreshCache
{
    my ($self, $call) = @_;
die "are you sure you want to be here?\n"; 
#    foreach my $name (@{ $call_data->{$call} }) {
#	my $datasource = $data_sources->{$name}->{DATASOURCE};
#	my $duration   = $data_sources->{$name}->{DURATION};
#	my $data = &{$datasource}($self);
#	$self->{CACHE}->set( $name, $data, $duration.' s' );
#    }
}

sub getData
{
    my ($self, $name, %h) = @_;
    my ($t1,$t2,$data);

    return undef unless exists $data_sources->{$name};

    $t1 = &mytimeofday();
    $data = $self->{CACHE}->get( $name, \%h );
    return undef unless $data;
    $t2 = &mytimeofday();
    warn "got '$name' from cache in ", sprintf('%.6f s', $t2-$t1), "\n" if $self->{DEBUG};

    return $data;
}

sub getData_thisIsObsolete
{
    my ($self, $name, %h) = @_;
die "are you sure you want to be here?\n"; 

#    my $datasource = $data_sources->{$name}->{DATASOURCE};
#    my $duration   = $data_sources->{$name}->{DURATION};
#
#    my $t1 = &mytimeofday();
#
#    my $from_cache;
#    my $data;
#    $data = $self->{CACHE}->get( $name ) unless $h{nocache};
#    if (!defined $data) {
#	$data = &{$datasource}($self, %h);
#	$self->{CACHE}->set( $name, $data, $duration.' s') unless $h{nocache};
#	$from_cache = 0;
#    } else {
#	$from_cache = 1;
#    }
#
#    my $t2 = &mytimeofday();
#
#    warn "got '$name' from ",
#    ($from_cache ? 'cache' : 'DB'),
#    " in ", sprintf('%.6f s', $t2-$t1), "\n" if $self->{DEBUG};
#
#    return wantarray ? ($data, $from_cache) : $data;
}


# Returns the cache duration for a API call.  If there are multiple
# data sources in an API call then the one with the lowest duration is
# returned
sub getCacheDuration
{
    my ($self, $call) = @_;
    my $min;
# This needs some consideration...
#    foreach my $name (@{ $call_data->{$call} }) {
#	my $duration   = $data_sources->{$name}->{DURATION};
#	$min ||= $duration;
#	$min = $duration if $duration < $min;
#    }
    return $min;
}

sub checkAuth
{
  my ($self,%args) = @_;
  die "bad call to checkAuth\n" unless $self->{SECMOD};
  my $secmod = $self->{SECMOD};
  $secmod->reqAuthnCert();
  return getAuth();
}

sub getAuth
{
  my $self = shift;
  my ($secmod,$auth);

  $secmod = $self->{SECMOD};
  $auth = {
            STATE  => $secmod->getAuthnState(),
            ROLES  => $secmod->getRoles(),
            DN     => $secmod->getDN(),
          };
  $auth->{NODES} = $self->fetch_nodes(%{$auth}, with_ids => 1);

  return $auth;
}

1;
