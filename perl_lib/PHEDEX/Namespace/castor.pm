package PHEDEX::Namespace::castor;

=head1 NAME

PHEDEX::Namespace::castor - implement namespace framework for castor protocol

=cut

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
		STAGE_HOST	   => $ENV{STAGE_HOST},
		STAGE_SVCCLASS	   => $ENV{STAGE_SVCCLASS},
		RFIO_USE_CASTOR_V2 => $ENV{RFIO_USE_CASTOR_V2},
            );
  %options = (
		'help'		=> \$help,
		'verbose!'	=> \$params{VERBOSE},
		'debug+'	=> \$params{DEBUG},
		'nocache'	=> \$params{NOCACHE},
		'stage_host=s'	=> \$params{STAGE_HOST},
		'stage_svcclass=s'	=> \$params{STAGE_SVCCLASS},
		'rfio_use_castor_v2=s'	=> \$params{RFIO_USE_CASTOR_V2},
             );
  GetOptions(%options);
  my $self = \%params;
  bless($self, $class);
  $self->SUPER::_init( NAMESPACE => __PACKAGE__ );
  map { $self->{$_} = $h{$_} } keys %h;
  $self->{ENV} = join(' ',
			map { "$_=" . ( $self->{$_} || '' ) }
			( qw / STAGE_HOST STAGE_SVCCLASS RFIO_USE_CASTOR_V2 / )
		     );

  $self->SUPER::_init_commands;
  print Dumper($self) if $self->{DEBUG};
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
 --stage_host, --stage_svcclass, and --rfio_use_castor_v2 to specify their
 counterparts in the environment. The defaults for these are taken from the
 environment

 Commands known to this module:
EOF

  $self->SUPER::_help();
}

1;
