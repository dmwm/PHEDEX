package PHEDEX::Core::Agent::Cycle;

use strict;
use warnings;
use POE;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my $self = {};
  bless $self, $class;

  $self->{_AL} = $h{_AL};

# Start a POE session for myself
  POE::Session->create
     (
      object_states =>
      [
         $self =>
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

  return $self;
}

# this workaround is ugly but allow us NOT rewrite everything
sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  return unless $attr =~ /[^A-Z]/;      # skip all-cap methods

  # if $attr exits, catch the reference to it, note we will call something
  # only if belogs to the parent calling class.
  if ( $self->{_AL}->can($attr) ) { $self->{_AL}->$attr(@_); } 
  else { PHEDEX::Core::Logging::Alert($self,"Unknown method $attr for Agent::Cycle"); }     
}

# Check if the agent should stop.  If the stop flag is set, cleans up
# and quits.  Otherwise returns.
sub maybeStop
{
    my $self = shift;

    # Check for the stop flag file.  If it exists, quit: remove the
    # pidfile and the stop flag and exit.
    return if ! -f $self->{_AL}->{STOPFLAG};
    $self->Note("exiting from stop flag");
    $self->Notify("exiting from stop flag");
    $self->doStop();
}

sub doExit{ my ($self,$rc) = @_; exit($rc); }

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
  $self->{_AL}->{SESSION_ID} = $session->ID;
  $kernel->yield('_preprocess');
  if ( $self->{_AL}->can('_poe_init') )
  {
    $kernel->state('_poe_init',$self->{_AL});
    $kernel->yield('_poe_init');
  }
  $kernel->yield('_process_start');
  $kernel->yield('_maybeStop');

  $self->Logmsg('STATISTICS: Reporting every ',$self->{_AL}->{STATISTICS_INTERVAL},' seconds, detail=',$self->{_AL}->{STATISTICS_DETAIL});
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
  $self->{_AL}->{_DONTSTOPME} = 1;
  $self->process();

  $kernel->yield('_process_stop');
}

sub _process_stop
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my $t;

  if ( $self->{_AL}->{_DOINGSOMETHING} )
  {
    $self->Dbgmsg("waiting for something: ",$self->{_AL}->{_DOINGSOMETHING}) if $self->{_AL}->{DEBUG};
    $kernel->delay_set('_process_stop',1);
    return;
  }

  if ( exists($self->{stats}{process}) )
  {
    $t = time;
    push @{$self->{stats}{process}{onCPU}}, $t - $self->{_start};
    $self->{stats}{process}{_offCPU} = $t;
  }

  $self->{_AL}->{_DONTSTOPME} = 0;

  $kernel->delay_set('_process_start',$self->{_AL}->{WAITTIME}) if $self->{_AL}->{WAITTIME};
}

sub _maybeStop
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];

  $kernel->delay_set('_maybeStop', 1);
  my $DontStopMe = $self->{_AL}->{_DONTSTOPME} || 0;
  if ( !$DontStopMe )
  {
    $self->Dbgmsg("starting '_maybeStop'") if $self->{_AL}->{VERBOSE} >= 3;
    $self->{stats}{maybeStop}++ if exists $self->{stats}{maybeStop};

    $self->maybeStop();
    $self->Dbgmsg("ending '_maybeStop'") if $self->{_AL}->{VERBOSE} >= 3;
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
  my ($delay,$totalWall,$totalOnCPU,$totalOffCPU,$summary);
  my ($pmon,$h,$onCPU,$offCPU,$count);

  $totalWall = $totalOnCPU = $totalOffCPU = 0;
  $pmon = $self->{_AL}->{pmon};
  $summary = '';
  $h = $self->{stats};
  if ( exists($h->{maybeStop}) )
  {
    $summary .= ' maybeStop=' . $h->{maybeStop};
    $self->{stats}{maybeStop}=0;
  }

  $onCPU = $offCPU = 0;
  $delay = 0;
  if ( exists($h->{process}) )
  {
    $count = $h->{process}{count} || 0;
    $summary .= sprintf(" process_count=%d",$count);
    my (@a,$max,$median);
    if ( $h->{process}{onCPU} )
    {
      @a = sort { $a <=> $b } @{$h->{process}{onCPU}};
      foreach ( @a ) { $onCPU += $_; }
      $totalOnCPU += $onCPU;
      $max = $a[-1];
      $median = $a[int($count/2)];
      $summary .= sprintf(" onCPU(wall=%.2f median=%.2f max=%.2f)",$onCPU,$median,$max);
      if ( $self->{_AL}->{STATISTICS_DETAIL} > 1 )
      {
        $summary .= ' onCPU_details=(' . join(',',map { $_=int(1000*$_)/1000 } @a) . ')';
      }
    }

    if ( $h->{process}{offCPU} )
    {
      @a = sort { $a <=> $b } @{$h->{process}{offCPU}};
      foreach ( @a ) { $offCPU += $_; }
      $totalOffCPU += $offCPU;
      $max = $a[-1];
      $median = $a[int($count/2-0.9)];
      my $waittime = $self->{_AL}->{WAITTIME} || 0;
      if ( !defined($median) ) { print "median not defined\n"; }
      if ( !defined($max   ) ) { print "max    not defined\n"; }
      $summary .= sprintf(" offCPU(median=%.2f max=%.2f)",$median,$max);
      if ( $waittime && $median )
      {
        $delay = $median / $waittime;
        $summary .= sprintf(" delay_factor=%.2f",$delay);
      }
      if ( $self->{_AL}->{STATISTICS_DETAIL} > 1 )
      {
        $summary .= ' offCPU_details=(' . join(',',map { $_=int(1000*$_)/1000 } @a) . ')';
      }
    }

    $self->{stats}{process} = undef;
  }

  if ( $summary )
  {

    $summary = 'AGENT_STATISTICS' . $summary;
    $self->Logmsg($summary) if $self->{_AL}->{STATISTICS_DETAIL};
    $self->Notify($summary);
  }

  my $now = time;
  $totalWall = $now - $self->{stats}{START}+.00001;
  my $busy= 100*$totalOnCPU/$totalWall;
  $summary = 'AGENT_STATISTICS';
  $summary=sprintf('TotalCPU=%.2f busy=%.2f%%',$totalOnCPU,$busy);
  ($self->Logmsg($summary),$self->Notify($summary)) if $totalOnCPU;
  $self->{stats}{START} = $now;

  $summary = 'AGENT_STATISTICS ';
  $summary .= $pmon->FormatStats($pmon->ReadProcessStats);

# If the user explicitly loaded the Devel::Size module, report the size of this agent
  my $size;
  if ( $size = PHEDEX::Monitoring::Process::total_size($self) )
  { $summary .= " Sizeof($self->{_AL}->{ME})=$size"; }
  if ( $size = PHEDEX::Monitoring::Process::TotalSizes() )
  { $summary .= " $size"; }
  $summary .= "\n";

  $self->Logmsg($summary);
  $self->Notify($summary);
  $kernel->delay_set('_make_stats',$self->{_AL}->{STATISTICS_INTERVAL});
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
