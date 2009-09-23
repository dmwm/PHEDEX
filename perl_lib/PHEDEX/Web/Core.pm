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
 * filter values with the value 'NULL' will match NULL (undefined) results

examples:

 ...?node=A&node=B&node=C
    node matches A, B, or C; but not D, E, or F
 ...?node=foo*&op=node:and&node=!foobar
    node matches 'foobaz', 'foochump', but not 'foobar'

=cut

use warnings;
use strict;

use base 'PHEDEX::Core::DB';
use PHEDEX::Core::Loader;
use PHEDEX::Core::Timing;
use CMSWebTools::SecurityModule::Oracle;
use PHEDEX::Web::Util;
use PHEDEX::Web::Cache;
use PHEDEX::Web::Format;
use HTML::Entities; # for encoding XML

our (%params);
%params = ( CALL => undef,
            VERSION => undef,
            DBCONFIG => undef,
	    INSTANCE => undef,
	    REQUEST_URL => undef,
            REMOTE_HOST => undef,
            USER_AGENT => undef,
	    REQUEST_TIME => undef,
	    SECMOD => undef,
	    DEBUG => 0,
	    CONFIG_FILE => undef,
            CONFIG => undef,
	    CACHE_CONFIG => undef,
	    SECMOD_CONFIG => undef,
	    AUTHZ => undef
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

    # Load the API component
    my $loader = PHEDEX::Core::Loader->new( NAMESPACE => 'PHEDEX::Web::API' );
    my $module = $loader->Load($self->{CALL});
    $self->{API} = $module;

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
    my ($self, $format, %args) = @_;
    no strict 'refs';

    # check the format argument then remove it
    if (!grep $_ eq $format, qw( xml json perl )) {
        &PHEDEX::Web::Format::error(*STDOUT, 'xml', "Return format requested is unknown or undefined");
	return;
    }

    my ($t1,$t2);

    $t1 = &mytimeofday();
    &process_args(\%args);

    # create a 'phedex' element with useful metadata
    my $phedex = {};
    $phedex->{instance} = $self->{INSTANCE};
    $phedex->{request_version} = $self->{VERSION};
    $phedex->{request_url} = $self->{REQUEST_URL};
    $phedex->{request_call} = $self->{CALL};
    $phedex->{request_timestamp} = $self->{REQUEST_TIME};
    $phedex->{request_date} = &formatTime($self->{REQUEST_TIME}, 'stamp');
    $phedex = { phedex => $phedex };

    # try to get the (entire) result data from cache
    my $obj = $self->getData($self->{CALL}, %args);

    # otherwise, call the API
    if ( ! $obj )
    {
      my $api = $self->{API};
      my $nocache = exists $args{nocache} ? $args{nocache} : 0;
      eval {
	# determine whether we need authorization
	if ($api->can('need_auth') && $api->need_auth()) {
	    $self->initSecurity();
	    $nocache = 1;
	}

	# prevent API STDOUT from corrupting output
        open (local *STDOUT,'>/dev/null');

	# print the format header with the 'phedex' attributes
	$fmt->header($phedex);

	if ($api->can('spool')) {	
	    # if the API can spool its output, call the formatter each spool chunk
	    $obj = $api->spool($self, %args);
	    do {
		$fmt->output($obj);
	    } while ($obj = $api->spool() 
		     && $fmt->separator());
	    $nocache = 1; # if it was big enough to spool, don't cache it
	} elsif ($api->can('invoke')) {
	    # else, just get all the object data in one call
	    my $obj = $api->invoke($self, %args);
	    $fmt->output($obj);
	} else {
	    die "API error: cannot be called";
	}
	$fmt->footer($phedex);
      };
      if ($@) {
          $fmt->error("Error when making call '$self->{CALL}':  $@");
	  return;
      }
      $t2 = &mytimeofday();
      warn "api call '$self->{CALL}' complete in ", sprintf('%.6f s',$t2-$t1), "\n" if $self->{DEBUG};

      # set the cache
      $t1 = &mytimeofday();
      my $duration = $self->getCacheDuration() || 0;
      $self->{CACHE}->set( $self->{CALL}, \%args, $obj, $duration ) unless $nocache;
      $t2 = &mytimeofday();
      warn "api call '$self->{CALL}' cache set in ", sprintf('%.6f s',$t2-$t1), "\n" if $self->{DEBUG};
    } else {
      # object from cache
      $fmt->header($phedex);
      $fmt->output($obj);
      $fmt->footer($phedex);
    }
    
    return $obj;
}

# Cache controls
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



# Returns the cache duration for a API call.
sub getCacheDuration
{
    my ($self) = @_;
    my $duration = 0;
    my $api = $self->{API};
    $duration = $api->duration() if $api->can('duration');
    return $duration;
}

sub initSecurity
{
  my $self = shift;

  my %args;
  if ($self->{SECMOD_CONFIG}) {
      # If a config file is given, we use that
      $args{CONFIG} = $self->{SECMOD_CONFIG};
  } else {
      # Otherwise we check for a "SecurityModule" section in DBParam, and use the defaults
      my $config = $self->{CONFIG};
      my $dbparam = { DBCONFIG => $config->{DBPARAM},
		      DBSECTION => 'SecurityModule' };
      bless $dbparam;
      eval {
	  &parseDatabaseInfo($dbparam);
      };
      if ($@ || !$dbparam) {
	  die "no way to initialize SecurityModule:  either configure secmod-config ",
	  "or provide SecurityModule section in the DBParam file",
	  ($@ ? ": parse error: $@" : ""), "\n";
      }
      $args{DBNAME} = $dbparam->{DBH_DBNAME};
      $args{DBUSER} = $dbparam->{DBH_DBUSER};
      $args{DBPASS} = $dbparam->{DBH_DBPASS};
      $args{LOGLEVEL} = ($config->{SECMOD_LOGLEVEL} || 3);
      $args{REVPROXY} = $config->{SECMOD_REVPROXY} if $config->{SECMOD_REVPROXY};
      # practically, no self sign-up
      $args{SIGNUP_HANDLER} = sub {
          die "authentication check failed:  user not registered in SiteDB\n"
          };
  }
  my $secmod = new CMSWebTools::SecurityModule::Oracle({%args});
  if ( ! $secmod->init() )
  {
      die("cannot initialise security module: " . $secmod->getErrMsg());
  }
  $self->{SECMOD} = $secmod;

  return 1;
}


sub checkAuth
{
  my ($self,%args) = @_;
  die "bad call to checkAuth\n" unless $self->{SECMOD};
  my $secmod = $self->{SECMOD};
  $secmod->reqAuthnCert();
  return $self->getAuth(%args);
}

sub getAuth
{
    my ($self, $ability) = @_;
    my ($secmod,$auth);

    $secmod = $self->{SECMOD};
    $auth = {
	STATE  => $secmod->getAuthnState(),
	ROLES  => $secmod->getRoles(),
	DN     => $secmod->getDN(),
    };
    $auth->{NODES} = $self->auth_nodes($self->{AUTHZ}, $ability, with_ids => 1);

    return $auth;
}

1;
