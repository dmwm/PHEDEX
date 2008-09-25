package PHEDEX::CLI::UserAgent;

=head1 NAME

PHEDEX::CLI::UserAgent - the PHEDEX::CLI::UserAgent object.

=head1 SYNOPSIS

This class inherits from LWP::UserAgent, and adds whatever fluff PhEDEx needs
on top of that to manage posting requests etc.

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

=cut

use strict;
use warnings;
use base 'LWP::UserAgent', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;
use Data::Dumper;
use Getopt::Long;

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
	  TIMEOUT	=> 5*60,

	  VERBOSE	=> $ENV{PHEDEX_VERBOSE} || 0,
	  DEBUG		=> $ENV{PHEDEX_DEBUG}   || 0,
	  FORMAT	=> undef,
	  INSTANCE	=> undef,
	  CALL		=> undef,

	  PARANOID	=> 1,
	  ME	 	=> 'PHEDEX::CLI::UserAgent',

	  CLEAN_ENVIRONMENT	=> 1,
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

  if ( $self->{CLEAN_ENVIRONMENT} || $self->{NOCERT} )
  {
    foreach ( map { "HTTPS_$_" } @env_keys ) { delete $ENV{$_} if $ENV{$_}; }
  }

  if ( !$self->{NOCERT} )
  {
    foreach ( @env_keys )
    {
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
    print "Bad response from server: ",$response->content(),"\n";
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
  return '/' . join('/',$self->{FORMAT},$self->{INSTANCE},$self->{CALL});
}

1;
