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

 FORMAT    the desired output format (e.g. xml, json, cjson, or perl)
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
 * filter values may contain the wildcard characters '?', '*', or '%'
   * '?' matches any single character
   * '*' and '%' -- they are exactly the same -- match any string
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
use PHEDEX::Web::FrontendAuth;
use PHEDEX::Web::Util;
use PHEDEX::Web::Format;
use HTML::Entities; # for encoding XML
use Digest::MD5;

use Carp qw / longmess /;
our (%params);
%params = ( CALL => undef,
            VERSION => undef,
            DBCONFIG => undef,
	    INSTANCE => undef,
	    REQUEST_URL => undef,
            REMOTE_HOST => undef,
            USER_AGENT => undef,
	    REQUEST_TIME => undef,
            REQUEST_METHOD => undef,
	    SECMOD => undef,
	    DEBUG => 0,
	    CONFIG_FILE => undef,
            CONFIG => undef,
	    SECMOD_CONFIG => undef,
	    AUTHZ => undef,
            REQUEST_HANDLER => undef,
	    HEADERS_IN => undef,
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

# prepare_call() -- before calling the API
#
# This is called before the header was sent out (in DataService.pm)
# Therefore, any cookies generated here could be attached to the header
#
# The primary purpose was for password authentication, yet it could
# be generalized for other pre-call checks.
#
sub prepare_call
{
    my ($self, $format, %args) = @_;
    my $api = $self->{API};

    eval {
        # check allowed methods
        if ($api->can('methods_allowed'))
        {
            my @allowed_mathods = $api->methods_allowed();
            if (! grep $self->{REQUEST_METHOD} eq $_, @allowed_mathods)
            {
                die "method ".$self->{REQUEST_METHOD}." is not allowed";
            }
        }
    
        # determine whether we need authorization
        my $need_auth = $api->need_auth() if $api->can('need_auth');
        if ($need_auth) {
            $self->initSecurity();
        }
    };

    # pass along the error message, if any.
    return $@;
}

sub call
{
    my ($self, $format, %args) = @_;
    no strict 'refs';

    # check the format argument then remove it
    if (!grep $_ eq $format, qw( xml json cjson perl )) {
        &PHEDEX::Web::Format::error(*STDOUT, 'xml', "Return format requested is unknown or undefined");
	return;
    }

    my ($t1,$t2);

    $t1 = &mytimeofday();
    &process_args(\%args);

    my $obj;
    my $stdout = '';
      my $api = $self->{API};
      my $result = eval {
	if ( $self->{CONFIG}{TRAP_WARNINGS} )
	{
	  $SIG{__WARN__} = sub
	    {
	      my $msg = longmess @_;
	      my @l = split("\n",$msg);
	      $msg = '';
	      foreach ( @l )
	      {
	        $msg = $msg . $_ . "\n";
	        last if m%PHEDEX::Web::DataService%;
	      }
	      warn (scalar localtime," WARN: ",$msg);
	    };
	}

        if ($api->can('spool'))
        {
            my $fmt;
            # open (local *STDOUT,'>/dev/null');
            my $spool = $api . '::spool';
            $fmt = PHEDEX::Web::Format->new($format, *STDOUT);
            die "unknown format $format" if (not $fmt);

            #create header
            
            my $phedex = {};
            $phedex->{instance} = $self->{INSTANCE};
            $phedex->{request_version} = $self->{VERSION};
            $phedex->{request_url} = $self->{REQUEST_URL};
            $phedex->{request_call} = $self->{CALL};
            $phedex->{request_timestamp} = $self->{REQUEST_TIME};
            $phedex->{request_date} = &formatTime($self->{REQUEST_TIME}, 'stamp');
            $phedex = { phedex => $phedex };
            # try getting data before printing header
            $obj = $spool->($self, %args);
            # got to bail out early if there is an error
            if (defined $obj && !ref($obj))
            {
                return $obj;
            }
            $fmt->header($phedex);
            do
            {
                # error or data?
                if (defined $obj && !ref($obj))
                {
                    return $obj;
                }
                $fmt->output($obj);
            } while (($obj = $spool->($self, %args))
                     && $fmt->separator());
            $t2 = &mytimeofday();
            $fmt->footer($phedex, $t2-$t1);
        }
        elsif ($api->can('invoke'))
        {
            #open (local *STDOUT,'>',\$stdout);
            my $invoke = $api . '::invoke';
	    # make the call
            $obj = $invoke->($self, %args);
            # error or data?
            if (defined $obj && !ref($obj))
            {
                return $obj;
            }
            $t2 = &mytimeofday();
            my $duration = $self->getCacheDuration() || 0;
    # wrap the object in a 'phedex' element with useful metadata
            $obj->{stdout}->{'$t'} = $stdout if $stdout;
            $obj->{instance} = $self->{INSTANCE};
            $obj->{request_version} = $self->{VERSION};
            $obj->{request_url} = $self->{REQUEST_URL};
            $obj->{request_call} = $self->{CALL};
            $obj->{request_timestamp} = $self->{REQUEST_TIME};
            $obj->{request_date} = &formatTime($self->{REQUEST_TIME}, 'stamp');
            $obj->{call_time} = int(100_000*( $t2 - $t1))/100_000;
            $obj = { phedex => $obj };
            $t1 = &mytimeofday();
            &PHEDEX::Web::Format::output(*STDOUT, $format, $obj);
            $t2 = &mytimeofday();
            warn "api call '$self->{CALL}' delivered in ", sprintf('%.6f s', $t2-$t1), "\n" if $self->{DEBUG};
        }
        else
        {
            die "API error: can not be called";
        }
        warn "api call '$self->{CALL}' complete in ", sprintf('%.6f s',$t2-$t1), "\n" if $self->{DEBUG};
      };

      return $result if $result;

      # check http-error
      if ($@) {
	  my $message = $@;
	  if ($message =~ /ORA-00942/) { # table or view doesn't exist
	    $message = 'Unexpected database error. Please try again later, or contact experts if you suspect a bug';
          } elsif ( $message =~ m%was called% ) {
            my $id = Digest::MD5::md5_hex($message);
            warn("id=$id, api=$self->{CALL}: $message");
            $message = "see logfile for details (id=$id)";
          }
          my ($error,$text);
          ($error,$text) = PHEDEX::Web::Util::decode_http_error($message);
          if ( $error ) { return [$error,$text]; }
          &PHEDEX::Web::Format::error(*STDOUT, $format, "Error when making call '$self->{CALL}':  $message");
	  return;
      }
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
        if ( $@ !~ m/database parameters not found/ ) {
 	  die "no way to initialize SecurityModule:  either configure secmod-config ",
	  "or provide SecurityModule section in the DBParam file",
	  ($@ ? ": parse error: $@" : ""), "\n";
        }
      }
      $args{DBNAME} = $dbparam->{DBH_DBNAME};
      $args{DBUSER} = $dbparam->{DBH_DBUSER};
      $args{DBPASS} = $dbparam->{DBH_DBPASS};
  }
  my $secmod = new PHEDEX::Web::FrontendAuth({%args});
  if ( ! $secmod->init($self) )
  {
      die "cannot initialise security module\n";
  }
  $self->{SECMOD} = $secmod;

# If we are testing, make sure the FrontendAuth module knows about it
  if ( $self->{CONFIG}{TESTING_MODE} ) {
    my @nodes = PHEDEX::Web::Util::fetch_nodes($self);
    $self->{SECMOD}->setTestNodes(\@nodes);
  }

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
