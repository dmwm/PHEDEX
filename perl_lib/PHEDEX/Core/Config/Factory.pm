package PHEDEX::Core::Config::Factory;

=head1 NAME

PHEDEX::Core::Config::Factory - a module for creating agents

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';
use POE;
use PHEDEX::Core::Timing;
use PHEDEX::Core::JobManager;
use IO::Socket::INET;
use constant DATAGRAM_MAXLEN => 1024;

$PHEDEX::Core::Factory::rerun = 0;

our %params =
	(
	  MYNODE	=> undef,		# my TMDB nodename
	  ME		=> 'AgentFactory',
	  WAITTIME	=> 90 + rand(3),	# This agent cycle time
	  VERBOSE	=> $ENV{PHEDEX_VERBOSE} || 0,
	  DEBUG		=> $ENV{PHEDEX_DEBUG} || 0,
	  AGENT_LIST	=> undef,		# Which agents am I to start?
	  CONFIG	=> $ENV{PHEDEX_CONFIG_FILE},
	  NODAEMON	=> 1,			# Don't daemonise by default!
	  REALLY_NODAEMON=> 0,			# Do daemonise eventually!
	  NJOBS		=> 3,			# start 3 agents at a time

	  LAST_SEEN_ALERT	=> 60*120,	# send alerts & restart after this much inactivity
	  LAST_SEEN_WARNING	=> 60*75,	# send warnings after this much inactivity
	  TIMEOUT		=> 11,		# interval between signals

	  STATISTICS_INTERVAL	=> 3600*12,	# My own reporting frequency
	  STATISTICS_DETAIL	=>    0,	# reporting level: 0, 1, or 2
	);

our @array_params = qw / AGENT_NAMES /;
our @hash_params  = qw / /;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(%params,@_);

  undef $self->{NOTIFICATION_PORT}; # Don't talk to myself...
  bless $self, $class;
  return $self;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

sub reloadConfig
{
  my ($self,$Config) = @_;
  my $config = $Config->select_agents($self->{LABEL});
  foreach ( qw / AGENT_LIST LAST_SEEN_ALERT LAST_SEEN_WARNING TIMEOUT / )
  {
    $self->{$_} = $config->{OPTIONS}{$_} if $config->{OPTIONS}{$_};
  }
  $self->createAgents();
}

sub createAgents
{
  my $self = shift;
  my ($Config,$Agent,%Agents,%Modules,$agent);
  $Config = $self->{CONFIGURATION};

  if ( ref($self->{AGENT_LIST}) ne 'ARRAY' )
  { $self->{AGENT_LIST} = [ $self->{AGENT_LIST} ]; }

  foreach $agent ( @{$self->{AGENT_LIST}} )
  {
    $self->Logmsg("Lookup agent \"$agent\"");
    $Agent = $Config->select_agents( $agent );

#   Paranoia!
    if ( $agent ne $Agent->LABEL )
    {
      die "given \"$agent\", but found \"",$Agent->LABEL,"\"\n";
    }
    if ( $Agent->PROGRAM =~ m%^PHEDEX::% )
    {
      my $module = $Agent->PROGRAM;
      $self->Logmsg("$agent is in $module");
      if ( !exists($Modules{$module}) )
      {
        $self->Logmsg("Attempt to load $module");
        eval("use $module");
        do { chomp ($@); die "Failed to load module $module: $@\n" } if $@;
        $Modules{$module}++;
      }
      my %a = @_;
      $a{NODAEMON} = 1;
      $a{LABEL} = $agent;
      my $opts = $Agent->OPTIONS;
      $opts->{DROPDIR} = '${PHEDEX_STATE}/' . $agent;
      $opts->{LOGFILE} = '${PHEDEX_LOGS}/'  . $agent;
      $opts->{SHARED_DBH} = 1 unless exists($opts->{SHARED_DBH});

      my $env = $Config->{ENVIRONMENTS}{$Agent->ENVIRON};
      foreach ( keys %{$opts} )
      {
        $a{$_} = $env->getExpandedString($opts->{$_}) unless exists($a{$_});
      }
      $Agents{$agent}{self} = eval("new $module(%a)");
      do { chomp ($@); die "Failed to create agent $module: $@\n" } if $@;

#     Enable statistics for this agent
      $Agents{$agent}{self}{stats}{process} = undef;
    }
    else
    {
      my $env = $self->{ENVIRONMENT};
      my $scripts = $env->getExpandedParameter('PHEDEX_SCRIPTS');
      my $Master = $scripts . '/Utilities/Master';
      my @cmd = ($Master,'--nocheckdb','--config',$self->{CONFIG},'start',$agent);
      $Agents{$agent}{cmd} = \@cmd;
    }
  }

# Monitor myself too!
  $Agents{$self->{ME}}{self} = $self;
  $self->Logmsg('I am running these agents: ',join(', ',sort keys %Agents));
  return ($self->{AGENTS} = \%Agents);
}

sub really_daemon
{
# I need these gymnastics because the Factory must not become a daemon until
# it has started all the agents, then it should do it's stuff. I should clean
# this up if I can.
  my $self = shift;
  $self->{NODAEMON} = $self->{REALLY_NODAEMON} || 0;
  my $pid = $self->SUPER::daemon( $self->{ME} );
  $self->Logmsg('I have successfully become a daemon');
}

sub idle
{
  my $self = shift;

  my ($agent,$Agent,$Config,$pidfile,$pid,$env,$stopfile);
  my ($now,$last_seen,$mtime);

  $now = time();
  $Config = $self->{CONFIGURATION};

  foreach $agent ( keys %{$self->{AGENTS}} )
  {
    next if $self->ME() eq $agent;
    if ( $self->{AGENTS}{$agent}{cmd} )
    {
#     This one was started externally, so check the PID and time since we last heard from it
      $Agent = $Config->select_agents( $agent );
      $env = $Config->{ENVIRONMENTS}{$Agent->ENVIRON};
      $pidfile = $env->getExpandedString($Agent->PIDFILE());
      undef $pid;
      if ( open PID, "<$pidfile" )
      {
        $pid = <PID>;
        close PID;
        chomp $pid;
      }
      if ( $pid && (kill 0 => $pid) )
      {
        if ( !$self->{AGENT_PID}{$pid} ) { $self->{AGENT_PID}{$pid} = $Agent->LABEL; }
        if ( !$self->{AGENTS}{$agent}{last_seen} ) { $self->{AGENTS}{$agent}{last_seen} = $now; }
        $last_seen = $self->{AGENTS}{$agent}{last_seen};
        $last_seen = $now - $last_seen;
        if ( $last_seen > $self->{LAST_SEEN_ALERT} )
        {
	  $self->Alert("Agent=$agent, PID=$pid, no news for $last_seen seconds");
          POE::Kernel->post($self->{SESSION_ID},'restartAgent',{ AGENT => $agent, PID => $pid });
	}
	elsif ( $last_seen > $self->{LAST_SEEN_WARNING} )
        {
	  $self->Warn("Agent=$agent, PID=$pid, no news for $last_seen seconds");
	}

#       $self->Dbgmsg("Agent=$agent, PID=$pid, LAST_SEEN=$last_seen, still alive...") if $self->{DEBUG};
        next;
      }

#     Now check for a stopfile, which means the agent _should_ be down
      $stopfile = $env->getExpandedString($Agent->DROPDIR) . 'stop';
      if ( -f $stopfile )
      {
        $self->Logmsg("Agent=$agent is down by request, not restarting...");
        next;
      }

#     Agent is down and should not be. Create a jobmanager if I don't have one, and restart the agent
      $self->Logmsg("Agent=$agent is down. Starting...");
      my $cmd = $self->{AGENTS}{$agent}{cmd};
      if ( !$self->{JOBMANAGER} )
      {
        $self->{JOBMANAGER} = PHEDEX::Core::JobManager->new (
                              NJOBS     => $self->{NJOBS},
                              VERBOSE   => $self->{VERBOSE},
                              DEBUG     => $self->{DEBUG},
			      KEEPALIVE => 0,
                            );
        $self->{JOBMANAGER}->whenQueueDrained( sub { delete $self->{JOBMANAGER}; } );
      }
      $self->{JOBMANAGER}->addJob(
			sub { $self->handleJob($agent) },
			{ TIMEOUT => 300 },
			@{$cmd}
		);
    }
    else
    {
#     This is either a session in the current process, or not in my list...
#     $self->Dbgmsg("Agent=$agent, in this process, ignore for now...") if $self->{DEBUG};
    }
  }
}

sub handleJob
{
  my ($self,$agent) = @_;
  $self->Logmsg("$agent started...");
  $self->{AGENTS}{$agent}{start}{time()}=1;
}

sub _poe_init
{
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];
  $kernel->state('restartAgent', $self);
  $kernel->state('_make_stats', $self);
  $kernel->state('_udp_listen', $self);
  $self->Logmsg('STATISTICS: Reporting every ',$self->{STATISTICS_INTERVAL},' seconds, detail=',$self->{STATISTICS_DETAIL});
  $self->{stats}{START} = time;
  $self->{stats}{maybeStop}=0;
  $kernel->delay_set('_make_stats',$self->{STATISTICS_INTERVAL});

  if ( $ENV{PHEDEX_NOTIFICATION_PORT} )
  {
    my $socket = IO::Socket::INET->new(
      Proto     => 'udp',
      LocalPort => $ENV{PHEDEX_NOTIFICATION_PORT},
    );
    $kernel->select_read($socket,'_udp_listen');
  }
}

sub restartAgent
{
  my ($self, $kernel, $h) = @_[OBJECT, KERNEL, ARG0];
  my ($agent,$pid,$signal);
  if ( ! $h->{signals} ) { $h->{signals} = [ qw / 1 15 3 9 9 / ]; }
  $signal = shift @{$h->{signals}};
  $pid = $h->{PID};
  $agent = $h->{AGENT};

# If the process is dead, there is nothing more to do...
  if ( ! (kill 0 => $pid) )
  {
    delete $self->{AGENT_PID}{$pid};
    return;
  }

# If we have run out of signals, there is nothing more we can do either...
  if ( !$signal )
  {
    $self->Alert("Cannot kill Agent=$agent, PID=$pid! Giving up...");
    return;
  }
  $self->Logmsg("Sending signal=$signal to pid=$pid (agent=$agent)");
  kill $signal => $pid;
  $kernel->delay_set('restartAgent',$self->{TIMEOUT},$h);
}

sub _udp_listen
{
  my ($self, $kernel, $socket) = @_[OBJECT, KERNEL, ARG0];
  my ($remote_address,$message);
  my ($agent,$pid,$label,$message_left);

  $message = '';
  $remote_address = recv($socket, $message, DATAGRAM_MAXLEN, 0);

  if ( $message =~ m%^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d: ([^[]+)\[(\d+)\]: (.*)$% )
  {
    $agent = $1;
    $pid = $2;
    $message_left = $3;
    return if ( $agent eq $self->ME() );
    if ( $message_left =~ m%^label=(\S+)$% )
    {
      $label = $1;
      $self->{AGENT_PID}{$pid} = $label;
    }
    $label = $self->{AGENT_PID}{$pid};
    $self->{AGENTS}{$label}{last_seen} = time() if $label;
    return if ( $message_left eq 'ping' ) # allows contact without flooding the logfile
  }
  print $message;
}

sub _make_stats
{
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];
  my ($delay,$totalWall,$totalOnCPU,$totalOffCPU);

  $totalWall = $totalOnCPU = $totalOffCPU = 0;
  foreach my $agent ( sort keys %{$self->{AGENTS}} )
  {
    next unless $self->{AGENTS}{$agent}{self}{stats};
    my $summary = "STATISTICS: $agent";
    my $h = $self->{AGENTS}{$agent}{self}{stats};
    if ( exists($h->{maybeStop}) )
    {
      $summary .= ' maybeStop=' . $h->{maybeStop};
      $self->{AGENTS}{$agent}{self}{stats}{maybeStop}=0;
    }

    my ($onCPU,$offCPU);
    $onCPU = $offCPU = 0;
    $delay = 0;
    if ( exists($h->{process}) )
    {
      my $count = $h->{process}{count} || 0;
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
        if ( $self->{STATISTICS_DETAIL} > 1 )
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
        my $waittime = $self->{AGENTS}{$agent}{self}->{WAITTIME} || 0;
        if ( !defined($median) ) { print "median not defined for $agent\n"; }
        if ( !defined($max   ) ) { print "max    not defined for $agent\n"; }
        $summary .= sprintf(" offCPU(median=%.2f max=%.2f)",$median,$max);
        if ( $waittime && $median )
        {
          $delay = $median / $waittime;
          $summary .= sprintf(" delay_factor=%.2f",$delay);
        }
        if ( $self->{STATISTICS_DETAIL} > 1 )
        {
          $summary .= ' offCPU_details=(' . join(',',map { $_=int(1000*$_)/1000 } @a) . ')';
        }
      }

      $self->{AGENTS}{$agent}{self}{stats}{process} = undef;
    }
    $self->Logmsg($summary) if $self->{STATISTICS_DETAIL};
    $self->Notify($summary,"\n") if $delay > 1.25;
  }

  $totalWall = time - $self->{stats}{START};
  if ( $totalWall )
  {
    my $busy= 100*$totalOnCPU/$totalWall;
    my $summary=sprintf('TotalCPU=%.2f busy=%.2f%%',$totalOnCPU,$busy);
    $self->Logmsg($summary);
  }
  $self->{stats}{START} = time;
  $kernel->delay_set('_make_stats',$self->{STATISTICS_INTERVAL});
}

1;
