package PHEDEX::Namespace::dcache;
use strict;
use warnings;
no strict 'refs';
use base 'PHEDEX::Namespace::Common'; # All interface packages must do this
use PHEDEX::Core::Loader;
use Data::Dumper;
use Getopt::Long;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my ($help,%params,%options);

# Params and options are interface-specific. If you need to set an environment
# variable or something, that parameter should be declared in %params, accepted
# as an input argument in %options, and used where necessary in the package.
  %params = (
		VERBOSE => 0,
		DEBUG   => 0,
                CACHE   => undef,
                NOCACHE => 0,
		PRELOAD	=> '',
                INPUT_FILE => undef,
            );
  %options = (
		'help'		=> \$help,
		'verbose!'	=> \$params{VERBOSE},
		'debug+'	=> \$params{DEBUG},
                'nocache'       => \$params{NOCACHE},
		'preload=s'	=> \$params{PRELOAD},
                'chimera_dump_file=s'  => \$params{INPUT_FILE},
             );
  GetOptions(%options);
  my $self = \%params;
  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;
  if ( exists($self->{AGENT})) {
    if ( exists($self->{AGENT}->{NOCACHE}) &&
       $self->{AGENT}->{NOCACHE} != $self->{NOCACHE}) { $self->{NOCACHE} = $self->{AGENT}->{NOCACHE}; }
$DB::single=1;
    foreach ( qw / INPUT_FILE PRELOAD / ) {
      if ( exists($self->{AGENT}->{$_}) ) { $self->{$_} = $self->{AGENT}->{$_}; }
    }
  }
  $self->SUPER::_init( NAMESPACE => __PACKAGE__ );
$DB::single=1;
  $self->{ENV} = 'LD_PRELOAD=' . $self->{PRELOAD};

# This is where the interface-specific modules are loaded. The modules are
# passed a reference to this object when they are loaded/created, so they
# can pick out the parameters you define above.
  $self->SUPER::_init_commands;
  print Dumper($self) if $self->{DEBUG};
  $self->Help if $help;
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
