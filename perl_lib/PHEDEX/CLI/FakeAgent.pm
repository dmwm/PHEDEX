package PHEDEX::CLI::FakeAgent;

=head1 NAME

PHEDEX::CLI::FakeAgent - the PHEDEX::CLI::FakeAgent object.

=head1 SYNOPSIS

This class inherits from LWP::UserAgent, and adds whatever fluff PhEDEx needs
on top of that to manage posting requests etc.

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

=cut

# TODO: set only the direct or proxy variables as required, pass proxy
# configuration to dataservice security module

use strict;
use warnings;
use base 'PHEDEX::CLI::UserAgent', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;
use Data::Dumper;
use Getopt::Long;
use Sys::Hostname;
use Socket;

our @env_keys = ( qw / PROXY DEBUG CERT_FILE KEY_FILE CA_FILE CA_DIR / );
our %env_keys = map { $_ => 1 } @env_keys;

our %params =
	(
	  URL		=> undef,
    	  CERT_FILE	=> undef,
	  KEY_FILE	=> undef,
	  CA_FILE	=> undef,
	  CA_DIR	=> undef,
	  NOCERT	=> undef,
	  PROXY		=> undef,
	  TIMEOUT	=> 30,

	  VERBOSE	=> $ENV{PHEDEX_VERBOSE} || 0,
	  DEBUG		=> $ENV{PHEDEX_DEBUG}   || 0,
	  FORMAT	=> undef,
	  INSTANCE	=> undef,
	  CALL		=> undef,

	  PARANOID	=> 1,
	  ME	 	=> 'PHEDEX::CLI::FakeAgent',

	  SERVICE	=> undef,
#	  Hope I'm not on a node with multiple network interfaces!
	  REMOTE_ADDR	=> inet_ntoa((gethostbyname(hostname))[4]),

	  CLEAN_ENVIRONMENT	=> 1,
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;

  my $self;
  $self = $class->SUPER::new();
  map { $self->{$_} = $params{$_} } keys %params;
  map { $self->{$_} = $h{$_}  if defined($h{$_}) } keys %h;
  bless $self, $class;

  $self->init();
  $self->agent($self->{ME} . ' ' . $self->_agent);
  return $self;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    if ( @_ )
    {
      $self->{$attr} = shift;
      $self->init() if exists $env_keys{$attr};
    }
    return $self->{$attr};
  }

  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  return $self->$parent(@_);
}

sub init
{
  my $self = shift;

  $self->SUPER::init();

  $ENV{HTTPS} = $ENV{HTTP_HTTPS} = $self->{NOCERT} ? 'off' : 'on';
  foreach ( qw / REMOTE_ADDR / )
  {
    $ENV{$_} = $self->{$_} if $self->{$_};
  }
}

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub target
{
  my $self = shift;
  my $path_info = $self->path_info();
  $ENV{PATH_INFO} = $path_info;
  return $self->{URL} . $path_info;
}

sub post
{
  $ENV{REQUEST_METHOD} = 'POST';
  return (shift)->_action(@_);
}

sub get
{
  $ENV{REQUEST_METHOD} = 'GET';
  return (shift)->_action(@_);
}

sub _action
{
  my ($self,$url,$args) = @_;
  my ($service,$service_name,$obj,$h,$r);
  if ( !$self->{NOCERT} )
  {
    $ENV{SSL_CLIENT_VERIFY} = $ENV{HTTP_SSL_CLIENT_VERIFY} = 'SUCCESS';
    defined($ENV{SSL_CLIENT_S_DN}) or
    do
    {
      open SSL, "openssl x509 -in $self->{CERT_FILE} -subject |" or
	die "SSL_CLIENT_S_DN environment variable not set and cannot read certificate to set it\n";
      my $in_cert_body = 0;
      my @cert_lines;
      $ENV{SSL_CLIENT_CERT} = "";
        while ( <SSL> )
        {
	    if (m%^subject=\s+(.*)$%) {
		$ENV{SSL_CLIENT_S_DN} = $1;
	    }
	    if (/BEGIN CERTIFICATE/) { $in_cert_body = 1; }
	    if ($in_cert_body) {
		chomp;
		push @cert_lines, $_;
	    }
	    if (/END CERTIFICATE/) { $in_cert_body = 0; }
        }
        close SSL; # Who cares about return codes...?
      $ENV{SSL_CLIENT_CERT} = join(' ', @cert_lines);
    } or die "SSL_CLIENT_S_DN environment variable not set\n";
    $ENV{HTTP_SSL_CLIENT_S_DN} = $ENV{SSL_CLIENT_S_DN};
    $ENV{HTTP_SSL_CLIENT_CERT} = $ENV{SSL_CLIENT_CERT};
  }
  $service_name = $self->{SERVICE};
  open (local *STDOUT,'>',\(my $stdout)); # capture STDOUT of $call
  eval("use $service_name");
  die $@ if $@;
  $service = $service_name->new();
  $h = HTTP::Headers->new();
  foreach ( split("\r\n", $stdout) )
  {
    m%^([^:]*):\s+(.+)\s*$% or next; # die "Dunno what to do about \"$_\"\n";
    $h->header( "$1" => $2 );
  }

# open (local *STDOUT,'>','/dev/null'); # capture STDOUT of $call
  $service->init_security();

  $service->{ARGS}{$_} = $args->{$_} for keys %{$args};
  $obj = $service->invoke();
  if ( $@ )
  {
    print STDERR Data::Dumper->Dump( [ $self, $service ], [ __PACKAGE__, $service_name ] );
    die $@;
  }
  $r = HTTP::Response->new( 200, 'Fake successfull return', $h, Dump($obj) );
  return $r;
}

1;
