package PHEDEX::Namespace::castor;

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
		STAGE_HOST	   => $ENV{STAGE_HOST},
		STAGE_SVCCLASS	   => $ENV{STAGE_SVCCLASS},
		RFIO_USE_CASTOR_V2 => $ENV{RFIO_USE_CASTOR_V2},
            );
  %options = (
		'stage_host=s'	=> \$params{STAGE_HOST},
		'stage_svcclass=s'	=> \$params{STAGE_SVCCLASS},
		'rfio_use_castor_v2=s'	=> \$params{RFIO_USE_CASTOR_V2},
             );
  PHEDEX::Namespace::Common::getCommonOptions(\%options,\%params);

  GetOptions(%options);
  my $self = \%params;
  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;
  $self->SUPER::_init( NAMESPACE => __PACKAGE__,
		       CATALOGUE => $h{CATALOGUE},
		       PROTOCOL => $h{PROTOCOL} );
  $self->{ENV} = join(' ',
			map { "$_=" . ( $self->{$_} || '' ) }
			( qw / STAGE_HOST STAGE_SVCCLASS RFIO_USE_CASTOR_V2 / )
		     );

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
 --nocache to disable the caching mechanism
 --stage_host, --stage_svcclass, and --rfio_use_castor_v2 to specify their
 counterparts in the environment. The defaults for these are taken from the
 environment

 Commands known to this module:
EOF

  $self->SUPER::_help();
}

1;
