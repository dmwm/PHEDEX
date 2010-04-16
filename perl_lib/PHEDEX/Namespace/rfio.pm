package PHEDEX::Namespace::rfio;

use strict;
use warnings;
no strict 'refs';
use base 'PHEDEX::Namespace::Common';
use PHEDEX::Core::Loader;
use Data::Dumper;
use Getopt::Long;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my ($help,%params,%options);

# Params and options are module-specific
  %params = (
		VERBOSE	 => 0,
		DEBUG	 => 0,
		CACHE	 => undef,
		NOCACHE	 => 0,
		RFIO_USE_CASTOR_V2 => 'YES',
            );
  %options = (
		'help'		=> \$help,
		'verbose!'	=> \$params{VERBOSE},
		'debug+'	=> \$params{DEBUG},
		'nocache'	=> \$params{NOCACHE},
		'rfio_use_castor_v2' => \$params{RFIO_USE_CASTOR_V2},
             );
  GetOptions(%options);
  my $self = \%params;
  bless($self, $class);
  $self->SUPER::_init( NAMESPACE => __PACKAGE__ );
  map { $self->{$_} = $h{$_} } keys %h;

  $self->{ENV} = "RFIO_USE_CASTOR_V2=" . ($self->{RFIO_USE_CASTOR_V2} || '');
  $self->SUPER::_init_commands;

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
 --nocache            to disable the caching mechanism
 --rfio_use_castor_v2 to specify their counterparts in the environment. The default is set to 'YES'

 Commands known to this module:



 Commands known to this module:
EOF

  $self->SUPER::_help();
}

1;
