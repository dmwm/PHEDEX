package PHEDEX::Testbed::Lifecycle::Examples;

use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use Time::HiRes;
use POE;
use Carp;
use Clone qw( clone );
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
  my $workflow = $payload->{workflow};

  push @{$workflow->{Events}}, 'backoff';
  $workflow->{Intervals}{backoff} ||= 0;
  $workflow->{Intervals}{backoff}++;
  $self->Logmsg('Back off for ',$workflow->{Intervals}{backoff},' seconds');
  $kernel->yield('nextEvent',$payload);
}

sub ping
{
  my ($self,$kernel,$payload) = @_[ OBJECT, KERNEL, ARG0 ];
  push @{$payload->{workflow}{Events}}, 'pong';
  $self->Logmsg('Ping...');
  $kernel->yield('nextEvent',$payload);
}

sub pong
{
  my ($self,$kernel,$payload) = @_[ OBJECT, KERNEL, ARG0 ];
  push @{$payload->{workflow}{Events}}, 'ping';
  $self->Logmsg('Pong...');
  $kernel->yield('nextEvent',$payload);
}

sub counter
{
  my ($self,$kernel,$payload) = @_[ OBJECT, KERNEL, ARG0 ];
  $payload->{workflow}{counter}++;
  $self->Logmsg('Counter: count=',$payload->{workflow}{counter});
  $kernel->yield('nextEvent',$payload);
}

sub fork_counter
{
  my ($self,$kernel,$payload) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($i,$p);
  for $i ( 1000, 2000, 3000 ) {
    $p = clone $payload;
    $p->{workflow}{counter} = $i;
    $p->{workflow}{Intervals}{counter} = 2 * int($i/1000);
    $self->Logmsg("fork_counter: create new workflow with counter=$i");
    $kernel->yield('nextEvent',$p);
  }
}

sub template
{
  my ($self,$kernel,$payload) = @_[ OBJECT, KERNEL, ARG0 ];
  my $workflow = $payload->{workflow};

  $kernel->yield('nextEvent',$payload);
}

1;
