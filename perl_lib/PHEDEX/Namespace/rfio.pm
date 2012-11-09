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
  my (%params,%options);

# Params and options are module-specific
  %params = (
		RFIO_USE_CASTOR_V2 => 'YES',
            );
  %options = (
		'rfio_use_castor_v2' => \$params{RFIO_USE_CASTOR_V2},
             );
  PHEDEX::Namespace::Common::getCommonOptions(\%options,\%params);

  GetOptions(%options);
  my $self = \%params;
  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;
  $self->SUPER::_init( NAMESPACE => __PACKAGE__,
		       CATALOGUE => $h{CATALOGUE},
		       PROTOCOL => $h{PROTOCOL} );

  $self->{ENV} = "RFIO_USE_CASTOR_V2=" . ($self->{RFIO_USE_CASTOR_V2} || '');
  $self->SUPER::_init_commands;

  $self->Help if $params{HELP};
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
 --rfio_use_castor_v2 to specify their counterparts in the environment, 
                      the default is set to 'YES'

 Commands known to this module:
EOF
  $self->SUPER::_help();
}

1;
