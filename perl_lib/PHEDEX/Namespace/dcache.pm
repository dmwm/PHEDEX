package PHEDEX::Namespace::dcache;
use strict;
use warnings;
no strict 'refs';
use base 'PHEDEX::Namespace::Common'; # All interface packages must do this
use PHEDEX::Core::Loader;
use Data::Dumper;
use Getopt::Long;
use PHEDEX::Namespace::SpaceCountCommon;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my (%params,%options);

# Params and options are interface-specific. If you need to set an environment
# variable or something, that parameter should be declared in %params, accepted
# as an input argument in %options, and used where necessary in the package.
  %params = (
              PRELOAD	=> '',
              INPUT_FILE => undef,
            );
  %options = (
              'preload=s'	=> \$params{PRELOAD},
              'chimera_dump_file=s'  => \$params{INPUT_FILE},
             );
  PHEDEX::Namespace::Common::getCommonOptions(\%options,\%params);

  GetOptions(%options);
  my $self = \%params;
  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;
  if ( exists($self->{AGENT})) {
    if ( exists($self->{AGENT}->{NOCACHE}) &&
       $self->{AGENT}->{NOCACHE} != $self->{NOCACHE}) { $self->{NOCACHE} = $self->{AGENT}->{NOCACHE}; }
    foreach ( qw / INPUT_FILE PRELOAD / ) {
      if ( exists($self->{AGENT}->{$_}) ) { $self->{$_} = $self->{AGENT}->{$_}; }
    }
  }
  $self->SUPER::_init( NAMESPACE => __PACKAGE__ ,
		       CATALOGUE => $h{CATALOGUE},
		       PROTOCOL => $h{PROTOCOL} );
  if ( $self->{PRELOAD} ) {
    $self->{ENV} = 'LD_PRELOAD=' . $self->{PRELOAD};
  }

# This is where the interface-specific modules are loaded. The modules are
# passed a reference to this object when they are loaded/created, so they
# can pick out the parameters you define above.
  $self->SUPER::_init_commands;
  print Dumper($self) if $self->{DEBUG};
  $self->Help if $params{HELP};
  return $self;
}

sub Help
{
# This function should describe any module-specific parameters, but the rest of
# it should remain unaltered.
  my $self = shift;
  print "\n Usage for ",__PACKAGE__,"\n";
  print <<EOF;

 This module takes the standard options:
 --nocache  to disable the caching mechanism
 --help, --(no)debug, --(no)verbose

 also:
 --preload  value to set in LD_PRELOAD in the environment before executing
 any client commands
 --chimera_dump_file  to be used in place of direct calls to the dcache system

 Commands known to this module:
EOF

  $self->SUPER::_help();
}

1;
