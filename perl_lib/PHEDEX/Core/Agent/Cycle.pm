package PHEDEX::Core::Agent::Cycle;

use strict;
use warnings;
use POE;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $agentLite = shift;
  my $self = {};

  no warnings 'redefine';
  *PHEDEX::Core::Agent::preprocess = \&PHEDEX::Core::Agent::Cycle::preprocess;
  *PHEDEX::Core::Agent::_start = \&PHEDEX::Core::Agent::Cycle::_start;
  *PHEDEX::Core::Agent::_preprocess = \&PHEDEX::Core::Agent::Cycle::_preprocess;
  *PHEDEX::Core::Agent::_process_start = \&PHEDEX::Core::Agent::Cycle::_process_start;
  *PHEDEX::Core::Agent::_process_stop = \&PHEDEX::Core::Agent::Cycle::_process_stop;
  *PHEDEX::Core::Agent::_maybeStop = \&PHEDEX::Core::Agent::Cycle::_maybeStop;
  *PHEDEX::Core::Agent::_stop = \&PHEDEX::Core::Agent::Cycle::_stop;
  *PHEDEX::Core::Agent::_make_stats = \&PHEDEX::Core::Agent::Cycle::_make_stats;
  *PHEDEX::Core::Agent::_child = \&PHEDEX::Core::Agent::Cycle::_child;
  *PHEDEX::Core::Agent::_default = \&PHEDEX::Core::Agent::Cycle::_default;

  bless $self, $class;

# Start a POE session for the parent class
  POE::Session->create
     (
      object_states =>
      [
         $agentLite =>
         {
            _preprocess         => '_preprocess',
            _process_start      => '_process_start',
            _process_stop       => '_process_stop',
            _maybeStop          => '_maybeStop',
            _make_stats         => '_make_stats',

            _start   => '_start',
            _stop    => '_stop',
            _child   => '_child',
            _default => '_default',
         },
      ],
     );

  $agentLite->{_Cycle} = $self;
  return $self;
}

# Introduced for POE-based agents to allow process to become a true loop
sub preprocess
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  # Restore signals.  Oracle apparently is in habit of blocking them.
  $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub { $self->doStop() };
}

# Actual session methods below
sub _start
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  $self->Logmsg("starting Agent session (id=",$session->ID,")");
  $self->{SESSION_ID} = $session->ID;
  $kernel->yield('_preprocess');
  if ( $self->can('_poe_init') )
  {
    $kernel->state('_poe_init',$self);
    $kernel->yield('_poe_init');
  }
  $kernel->yield('_process_start');
  $kernel->yield('_maybeStop');

  if ( $self->{STATISTICS_INTERVAL} ) {
    $self->Logmsg('STATISTICS: Reporting every ',$self->{STATISTICS_INTERVAL},' seconds, detail=',$self->{STATISTICS_DETAIL});
  } else {
    $self->Logmsg('STATISTICS: Not reporting, STATISTICS_INTERVAL not set');
  }
  $self->{stats}{START} = time;
  $kernel->yield('_make_stats');
  $self->Logmsg("has successfully initialised");
}

sub _preprocess
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  $self->preprocess() if $self->can('prepocess');
}

sub _process_start
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($t,$t1);

  if ( exists($self->{stats}{process}) )
  {
    $t = time;
    if ( defined($t1 = $self->{stats}{process}{_offCPU}) )
    {
      push @{$self->{stats}{process}{offCPU}}, $t - $t1;
      undef $self->{stats}{process}{_offCPU};
    }
    $self->{stats}{process}{count}++;
    $self->{_start} = time;
  }

# There are two paranoid sentinels to prevent being stopped in the middle
# of a processing loop. Agents can play with this as they wish if they are
# willing to allow themselves to be stopped in the middle of a cycle.
#
# The first, _DOINGSOMETHING, should only be set if you are using POE events
# inside your processing loop and want to wait for some sequence of them
# before declaring your cycle to be finished. Increment it or decrement it,
# the cycle will not be declared over until it reaches zero.
# _DOINGSOMETHING should not be set here, it's enough to let the derived
# agents increment it if they need to. Use the StartedDoingSomething() and
# FinishedDoingSomething() methods to manipulate this value.
#
# The second, _DONTSTOPME, tells the maybeStop event loop not to allow the
# agent to exit. Set this if you have critical ongoing events, such as
# waiting for a subprocess to finish.
  $self->{_DONTSTOPME} = 1;
  $self->process();

  $kernel->yield('_process_stop');
}

sub _process_stop
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my $t;

  if ( $self->{_DOINGSOMETHING} )
  {
    $self->Dbgmsg("waiting for something: ",$self->{_DOINGSOMETHING}) if $self->{DEBUG};
    $kernel->delay_set('_process_stop',1);
    return;
  }

  if ( exists($self->{stats}{process}) )
  {
    $t = time;
    push @{$self->{stats}{process}{onCPU}}, $t - $self->{_start};
    $self->{stats}{process}{_offCPU} = $t;
  }

  $self->{_DONTSTOPME} = 0;

  $kernel->delay_set('_process_start',$self->{WAITTIME}) if $self->{WAITTIME};
}

sub _maybeStop
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];

  $kernel->delay_set('_maybeStop', 1);
  my $DontStopMe = $self->{_DONTSTOPME} || 0;
  if ( !$DontStopMe )
  {
    $self->Dbgmsg("starting '_maybeStop'") if $self->{VERBOSE} >= 3;
    $self->{stats}{maybeStop}++ if exists $self->{stats}{maybeStop};

    $self->maybeStop();
    $self->Dbgmsg("ending '_maybeStop'") if $self->{VERBOSE} >= 3;
  }

}

sub _stop
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  print $self->Hdr("ending, for lack of work...\n");
}

sub _make_stats
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  return unless $self->{STATISTICS_INTERVAL};
  $self->make_stats();
  $kernel->delay_set('_make_stats',$self->{STATISTICS_INTERVAL});
}

# Dummy handler in case it's needed. Let's _default catch the real errors
sub _child {}

sub _default
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my $ref = ref($self);
  die <<EOF;

  Default handler for class $ref:
  The default handler caught an unhandled "$_[ARG0]" event.
  The $_[ARG0] event was given these parameters: @{$_[ARG1]}

  (...end of dump)
EOF
}

1;
