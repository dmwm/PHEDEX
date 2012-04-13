package PHEDEX::Testbed::Lifecycle::Examples;

use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use Time::HiRes;
use POE;
use Carp;
use Data::Dumper;

our %params = (
	  Verbose	=> undef,
	  Debug		=> undef,
        );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { parent => shift };
  my $workflow = shift;

  my $package;
  $self->{ME} = $package = __PACKAGE__;
  $package =~ s%^$workflow->{Namespace}::%%;

  my $p = $workflow->{$package};
  map { $self->{params}{uc $_} = $params{$_} } keys %params;
  map { $self->{params}{uc $_} = $p->{$_} } keys %{$p};
  map { $self->{$_} = $p->{$_} } keys %{$p};

  $self->{Verbose} = $self->{parent}->{Verbose};
  $self->{Debug}   = $self->{parent}->{Debug};
  bless $self, $class;
  return $self;
}

sub backoff
{
  my ($self,$kernel,$payload) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($workflow);
  $workflow = $payload->{workflow};

  push @{$workflow->{Events}}, 'backoff';
  $workflow->{Intervals}{backoff} ||= 0;
  $workflow->{Intervals}{backoff}++;
  $self->Logmsg('Back off for ',$workflow->{Intervals}{backoff},' seconds');
  $kernel->yield('nextEvent',$payload);
}

sub template
{
  my ($self,$kernel,$payload) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($workflow);
  $workflow = $payload->{workflow};

  $kernel->yield('nextEvent',$payload);
}

1;
