package PHEDEX::Namespace::srm;

=head1 NAME

PHEDEX::Namespace::srm - implement namespace framework for srm protocol

=cut

use strict;
use warnings;
no strict 'refs';
use base 'PHEDEX::Namespace::Common';
use PHEDEX::Core::Loader;
use Data::Dumper;
use Getopt::Long;

our $default_protocol_version = '2';
our $default_proxy_margin = 60;
sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my ($help,%params,%options);

# Params and options are module-specific
  %params = (
		VERBOSE		=> 0,
		DEBUG		=> 0,
		VERSION		=> $default_protocol_version,
		PROXY_MARGIN	=> $default_proxy_margin,
		CACHE		=> undef,
		NOCACHE		=> 0,
            );
  %options = (
		'help'		=> \$help,
		'verbose!'	=> \$params{VERBOSE},
		'version=s'	=> \$params{VERSION},
		'proxy_margin=i'=> \$params{PROXY_MARGIN},
		'debug+'	=> \$params{DEBUG},
		'nocache'	=> \$params{NOCACHE},
             );
  GetOptions(%options);
  my $self = \%params;
  bless($self, $class);
  $self->{PROXY_CHECK} = 0;
  $self->SUPER::_init( NAMESPACE => __PACKAGE__ . 'v' . $self->{VERSION} );
  map { $self->{$_} = $h{$_} } keys %h;
  $self->{ENV} = '';

  $self->SUPER::_init_commands;
  print Dumper($self) if $self->{DEBUG};
  $self->proxy_check if $self->{DEBUG};
  $self->Help if $help;
  return $self;
}

sub Help
{
  my $self = shift;
  print "\n Usage for ",__PACKAGE__,"\n";
  print <<EOF;

 This module takes the standard options:
 --help, --debug, --(no)verbose

 as well as these:
 --nocache to disable the caching mechanism
 --version specifies the protocol version. Default='$default_protocol_version'
 --proxy_margin require a proxy to be valid for at least this long or die.
	Default=$default_proxy_margin

 Commands known to this module:
EOF

  $self->SUPER::_help();
}

sub proxy_check
{
  my $self = shift;
  my $t = time;
  return if $self->{PROXY_CHECK} > $t; 

  my $timeleft = 0;
  open VPI, "voms-proxy-info -timeleft 2>/dev/null |" or
		 die "voms-proxy-info: $!\n";
  while ( <VPI> )
  {
    chomp;
    m%^\d+$% or next;
    $timeleft = $_;
  }
  close VPI; # don't care about RC, rely on output value instead
  if ( $timeleft < $self->{PROXY_MARGIN} )
  {
    die "Insufficient time left on proxy ($timeleft < $self->{PROXY_MARGIN})\n";
  }
  $self->{PROXY_CHECK} = $t + $timeleft - $self->{PROXY_MARGIN};
  if ( $self->{DEBUG} )
  {
    print "Proxy valid for another $timeleft seconds\n",
	  "Will bail out by ",scalar localtime $self->{PROXY_CHECK},"\n";
  }
}

1;
