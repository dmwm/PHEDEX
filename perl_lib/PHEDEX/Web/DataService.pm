package PHEDEX::Web::DataService;

=head1 NAME

Service - Main program of the PhEDEx data service

=head1 DESCRIPTION

Checks configuration, parses URL path for parameters, makes API call

=cut

use warnings;
use strict;

use CGI qw(header path_info url param Vars remote_host user_agent);

use PHEDEX::Web::Config;
use PHEDEX::Web::Core;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Loader;
use PHEDEX::Web::Format;

our ($TESTING, $TESTING_MAIL);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;

  my $self;
  map { $self->{$_} = $h{$_}  if defined($h{$_}) } keys %h;

  # Read PhEDEx web server configuration
  my $config_file = $self->{PHEDEX_SERVER_CONFIG} ||
		       $ENV{PHEDEX_SERVER_CONFIG} ||
    die "ERROR:  Web page config file not set (PHEDEX_SERVER_CONFIG)";

  my $dev_name = $self->{PHEDEX_DEV_NAME} || $ENV{PHEDEX_DEV_NAME};

  my $config = PHEDEX::Web::Config->read($config_file, $dev_name);
  $self->{CONFIG} = $config;
  $self->{CONFIG_FILE} = $config_file;

  # Set debug mode
  $TESTING = $$config{TESTING_MODE} ? 1 : 0;
  $TESTING_MAIL = $$config{TESTING_MAIL} || undef;

  eval "use CGI::Carp qw(fatalsToBrowser)" if $TESTING;

  bless $self, $class;
  return $self;
}

sub invoke
{
  my $self = shift;

  # Interpret the trailing path suffix: /FORMAT/DB/API?QUERY
  my $path = path_info() || "xml/prod";

  my ($format, $db, $call) = ("xml", "prod", undef);
  $format = $1 if ($path =~ m!\G/([^/]+)!g);
  $db =     $1 if ($path =~ m!\G/([^/]+)!g);
  $call =   $1 if ($path =~ m!\G/([^/]+)!g);

  # Print documentation and exit if we have the "doc" path
  if ($format eq 'doc') {
      &print_doc($call ? $call : $db, # the API to document
#		 $db ? 'doc/' : '');  # a prefix for URLs
                 ($path eq "/doc")? 'doc/' : ''
                 );
      return;
  }

  my $type;
  if    ($format eq 'xml')  { $type = 'text/xml'; }
  elsif ($format eq 'json') { $type = 'text/javascript'; }
  elsif ($format eq 'perl') { $type = 'text/plain'; }
  else {
      &xml_error("Unsupported format '$format'");
      return;
  }

  if (!$call) {
      &xml_error("API call was not defined.  Correct URL format is /FORMAT/INSTANCE/CALL?OPTIONS");
      return;
  }

  my $http_now = &formatTime(&mytimeofday(), 'http');

  # Get the query string variables
  my %args = Vars();

  # Reformat multiple value variables into name => [ values ]
  foreach my $key (keys %args) {
      my @vals = split("\0", $args{$key});
      $args{$key} = \@vals if ($#vals > 0);
  }

  # create the core
  my $config = $self->{CONFIG};
  my $core;
  
  eval {
      $core = new PHEDEX::Web::Core(CALL => $call,
				    VERSION => $config->{VERSION},
				    DBCONFIG => $config->{INSTANCES}->{$db}->{DBCONFIG},
				    INSTANCE => $db,
				    REQUEST_URL => url(-full=>1, -path=>1),
				    REMOTE_HOST => remote_host(), # TODO:  does this work in reverse proxy?
				    USER_AGENT => user_agent(),
				    DEBUG => $TESTING,
				    CONFIG_FILE => $self->{CONFIG_FILE},
				    CONFIG => $self->{CONFIG},
				    CACHE_CONFIG => $config->{CACHE_CONFIG} || {},
				    SECMOD_CONFIG => $config->{SECMOD_CONFIG},
				    AUTHZ => $config->{AUTHZ}
				    );
  };
  if ($@) {
      &xml_error("failed to initialize data service API '$call':  $@");
      return;
  }

  my %cache_headers;
  unless (param('nocache')) {
      # getCacheDuration needs re-implementing.
      my $duration = $core->getCacheDuration();
      $duration = 300 if !defined $duration;
      %cache_headers = (-Cache_Control => "max-age=$duration",
		        -Date => $http_now,
		        -Last_Modified => $http_now,
		        -Expires => "+${duration}s");
      warn "cache duration for '$call' is $duration seconds\n" if $TESTING;
  }

  print header(-type => $type, %cache_headers );
  return $core->call($format, %args);
}

# For printing errors before we know what the error format should be
sub xml_error
{
    my $msg = shift;
    print header(-type => 'text/xml');
    &PHEDEX::Web::Format::error(*STDOUT, 'xml', $msg);
}

sub print_doc
{
    my ($call, $prefix) = @_;

    chdir '/tmp';
    print header();
    my ($module,$module_name,$loader,@lines,$line);
    $loader = PHEDEX::Core::Loader->new ( NAMESPACE => 'PHEDEX::Web::API' );
    $module_name = $loader->ModuleName($call);
    $module = $module_name || 'PHEDEX::Web::Core';

    # This bit is ugly. I want to add a section for the commands known in this installation,
    # but that can only be done dynamically. So I have to capture the output of the pod2html
    # command and print it, but intercept it and add extra stuff at the appropriate point.
    # I also need to check that I am setting the correct relative link for the modules.
    @lines = `perldoc -m $module |
                pod2html --header -css /phedex/datasvc/static/phedex_pod.css`;

    my ($commands,$count);
    $count = 0;
    foreach $line ( @lines ) {
        if ( $line =~ m%^<table% ) {
	    $count++;
	    if ( $count != 2 ) { print $line; next; }
	    print qq{
		<h1><a name='See Also'>See Also</a></h1>
		Documentation for the commands known in this installation<br>
		<br/>
		<table>
		<tr> <td> Command </td> <td> Module </td> </tr>
		};

	    $commands = $loader->Commands();
	    foreach ( sort keys %{$commands} ) {
		$module = $loader->ModuleName($_);
		print qq{
		     <tr>
  		     <td><strong>$_</strong></td>
		     <td><a href='$prefix$_'>$module</a></td>
		     </tr>
		    };
	    }
	    print qq{
		</table>
		<br/>
		and <a href='.'>PHEDEX::Web::Core</a> for the core module documentation<br/>
		<br/>
		};
        }
        print $line;
    }
}

1;
