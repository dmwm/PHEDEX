package PHEDEX::CLI::UserAgent;

use strict;
use warnings;
use base 'LWP::UserAgent', "PHEDEX::Core::Logging";
use PHEDEX::Core::Timing;
use Data::Dumper;
use Getopt::Long;

our $VERSION = '1.0';
our @env_keys = ( qw / PROXY DEBUG CERT_FILE KEY_FILE CA_FILE CA_DIR / );
our %env_keys = map { $_ => 1 } @env_keys;

our %params =
	(
	  URL		=> undef,
    	  CERT_FILE	=> $ENV{X509_USER_PROXY} || "/tmp/x509up_u$<",
	  KEY_FILE	=> $ENV{X509_USER_PROXY} || "/tmp/x509up_u$<",
	  CA_FILE	=> $ENV{X509_USER_PROXY} || "/tmp/x509up_u$<",
	  CA_DIR	=> $ENV{X509_CERT_DIR} || "/etc/grid-security/certificates",
	  NOCERT	=> undef,
	  PROXY		=> undef,
	  TIMEOUT	=> 5*60,

	  VERBOSE	=> $ENV{PHEDEX_VERBOSE} || 0,
	  DEBUG		=> $ENV{PHEDEX_DEBUG}   || 0,
	  FORMAT	=> undef,
	  INSTANCE	=> undef,
	  CALL		=> undef,
	  TARGET	=> undef,

	  PARANOID	=> 1,
	  ME	 	=> __PACKAGE__ . '/' . $VERSION,
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new();
  map { $self->{$_} = $params{$_} } keys %params;
  my %h = @_;
  map { $self->{$_} = $h{$_}  if defined($h{$_}) } keys %h;
  bless $self, $class;

  $self->init();
  $self->CMSAgent($self->{ME});
  return $self;
}

sub CMSAgent
{
  my ($self,$string) = @_;
  $self->agent($string . ' (CMS) ' . $self->_agent);
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

  if ( $self->{NOCERT} ) {
    foreach ( map { "HTTPS_$_" } @env_keys ) { delete $ENV{$_} if $ENV{$_}; }
  } else {
    foreach ( @env_keys ) {
      $ENV{'HTTPS_' . $_} = $self->{$_} if $self->{$_};
    }
  }

  if ( $self->{DEBUG} ) { eval "use LWP::Debug qw(+);"; }
  $self->timeout( $self->{TIMEOUT} ) if $self->{TIMEOUT};
}

sub test_certificate
{
  my $self = shift;
  my ($url,$response);

  $url = shift ||
	 'https://grid-deployment.web.cern.ch/grid-deployment/cgi-bin/CertTest/CertTest.cgi';

  if ( $self->{VERBOSE} )
  {
    print $self->Hdr,'testing certificate with: URL=',$url;
    foreach ( sort @env_keys ) { print ' ',$_,'=',$self->{$_} || '(undef)'; }
    print "\n";
  }

  $response = $self->get($url);
  if ( !$self->response_ok($response) )
  {
    print "Bad response from server: ",$response->status_line,"\n";
    print "Server response: ",$response->content(),"\n";
    return;
  }

  $_ = $response->content;
  if ( m%Your certificate is recognised% )
  {
    print $self->Hdr,"Certificate recognised!\n" if $self->{VERBOSE};
    return 0;
  }
  else
  {
    print $self->Hdr,"Certificate not recognised:\n$_"
      if $self->{VERBOSE};
    return 1;
  }
}

sub response_ok
{
  my ($self,$response) = @_;

  if ( $response->is_success )
  {
    $_ = $response->content();
    s%\n%%g;
    if ( m%^<error>(.*)</error>$% )
    {
      print "Error from ",$response->request()->url(),"\n$1\n" if $self->{DEBUG};
      return 0 if $self->{PARANOID};
    }
    return 1;
  }

  return 0;
}

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub target
{
  my $self = shift;
  return $self->{URL} . $self->path_info();
}

sub path_info
{
  my $self = shift;
  return $self->{TARGET} if $self->{TARGET};
  my $path = '/' . join('/',$self->{FORMAT},$self->{INSTANCE},$self->{CALL});
  $path =~ s%//+%/%g;
  return $path;
}

sub get
{
  my ($self,$url,$h,$headers) = @_;
  my $args='';
  no strict 'vars';
  foreach my $key ( keys %{$h} )
  {
    if ( $args ) { $args .= '&'; }
    if ( ref($h->{$key}) eq 'ARRAY' ) {
      $args .= join( '&', map { "$key=" . ( $_ || '') } @{$h->{$key}} );
    } else {
      $args .= $key . '=' . ( $h->{$key} || '');
    }
  }
  if ( $args ) { $url .= '?' . $args; }
  my $response = $self->SUPER::get($url,%{$headers});
}

sub get_auth_options
{
  Getopt::Long::Configure('pass_through');
  my $optname;
  foreach ('CA_DIR', 'KEY_FILE', 'CERT_FILE', 'CA_FILE')
  {
    $optname = lc $_ ;
    GetOptions ( $optname . "=s" => \$params{$_});
  }
}

1;
