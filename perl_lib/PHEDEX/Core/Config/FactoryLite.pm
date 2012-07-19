package PHEDEX::Core::Config::FactoryLite;

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';
use POE;
use PHEDEX::Core::Timing;
use PHEDEX::Core::JobManager;
use PHEDEX::Core::Loader;
use IO::Socket::INET;
use constant DATAGRAM_MAXLEN => 1024*1024;

our %params =
	(
          ME                    => 'WatchdogLite',
	  VERBOSE	        => $ENV{PHEDEX_VERBOSE} || 0,
	  DEBUG		        => $ENV{PHEDEX_DEBUG} || 0,
          WAITTIME	        => 75 + rand(15), # This agent cycle time
	  NODAEMON	        => 1,		  # Don't daemonise by default!
	  REALLY_NODAEMON       => 0,		  # Do daemonise eventually!
	  LAST_SEEN_ALERT	=> 60*120,	  # 60*120 send alerts & restart after this much inactivity
	  LAST_SEEN_WARNING	=> 60*75,	  # 60*75 send warnings after this much inactivity
	  TIMEOUT		=> 11,		  # interval between signals
	  STATISTICS_INTERVAL	=> 3600*12,	  # My own reporting frequency
	  STATISTICS_DETAIL	=> 0,	          # reporting level: 0, 1, or 2
          LOAD_DROPBOX          => 0,             # Do not load Dropbox module
          LOAD_CYCLE            => 1,             # Load Cycle module
          LOAD_DB               => 0,             # Do not load DB module

          WATCHDOG_NOTIFICATION_PORT => 9999,     # Port to listen
	);

our @array_params = qw / AGENT_NAMES /;
our @hash_params  = qw / /; #/

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(%params,@_);

  $self->{NOTIFICATION_PORT} =
        $self->{ENVIRONMENT}->getExpandedParameter('PHEDEX_WATCHDOG_NOTIFICATION_PORT') ||
        $ENV{PHEDEX_WATCHDOG_NOTIFICATION_PORT} || $self->{WATCHDOG_NOTIFICATION_PORT};
  $self->{WATCHDOG_NOTIFICATION_PORT} = $self->{NOTIFICATION_PORT};

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

sub createAgents
{
  my $self = shift;
  my (%Agents,$agent);

  if ( ref($self->{AGENT_LIST}) ne 'ARRAY' )
  { $self->{AGENT_LIST} = [ $self->{AGENT_LIST} ]; }

  foreach $agent ( @{$self->{AGENT_LIST}} )
  {
    $self->Logmsg("Lookup agent \"$agent\"");

    my $env = $self->{ENVIRONMENT};
    my $scripts = $env->getExpandedParameter('PHEDEX_SCRIPTS');
    my $Master = $scripts . '/Utilities/Master';
    my @cmd = ($Master,'--nocheckdb','--config',$self->{CONFIG_FILE},'start',$agent);
    $Agents{lc($agent)}{cmd} = \@cmd;
  }

  $self->Logmsg('I am running these agents: ',join(', ',sort keys %Agents));
  return ($self->{AGENTS} = \%Agents);
}

sub really_daemon
{
  my $self = shift;
  $self->{NODAEMON} = $self->{REALLY_NODAEMON} || 0;
  my $pid = $self->SUPER::daemon( $self->{ME} );
  $self->Logmsg('I have successfully become a daemon');
}

sub processIdle 
{
  my $self = shift;

  my ($agent,$pid);
  my ($now,$last_seen);

  $now = time();

  foreach $agent ( keys %{$self->{AGENTS}} )
  {
    next if lc($self->ME()) eq $agent;
    if ( $self->{AGENTS}{$agent}{cmd} )
    {
#     Check the PID and time since we last heard from it
      undef $pid;
      $pid = $self->{AGENTS}{$agent}{pid};
      if ( $pid && (kill 0 => $pid)) {

        if ( !$self->{AGENTS}{$agent}{last_seen} ) { $self->{AGENTS}{$agent}{last_seen} = $now; }
        $last_seen = $now - $self->{AGENTS}{$agent}{last_seen};
        if ( $last_seen > $self->{LAST_SEEN_ALERT} )
        {
	  $self->Alert("Agent=$agent, PID=$pid, no news for $last_seen seconds here I should restart it");
          POE::Kernel->post($self->{SESSION_ID},'killAgent',{ AGENT => $agent, PID => $pid });
        }
        elsif ( $last_seen > $self->{LAST_SEEN_WARNING} )
        {
	  $self->Warn("Agent=$agent, PID=$pid, no news for $last_seen seconds");
        }
        next;
      } 
      elsif ( $pid ) 
      {
#       Agent is down and should not be. Reset pid
        $self->Alert("Agent=$agent, PID=$pid, is dead, trying to restart it ...");
        delete $self->{AGENTS}{$agent}{pid};
        next;
      }
      $self->startAgent($agent);
    }
    else
    {
#     This is either a session in the current process, or not in my list...
     $self->Dbgmsg("Agent=$agent, in this process, ignore for now...") if $self->{DEBUG};
    }
  }
}

sub startAgent
{
  my ($self,$agent) = @_;
  $self->Logmsg("Agent=$agent is down. Starting...");
  my $cmd = $self->{AGENTS}{$agent}{cmd};
  if ( !$self->{JOBMANAGER} )
  {
    $self->{JOBMANAGER} = PHEDEX::Core::JobManager->new (
                NJOBS     => $self->{NJOBS},
                VERBOSE   => 0,
                DEBUG     => 0,
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


sub handleJob
{
  my ($self,$agent) = @_;
  $self->Logmsg("$agent started, hopefully...");
}

sub _poe_init
{
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];
  $kernel->state('killAgent', $self);
  $kernel->state('_udp_listen', $self);
  $self->Logmsg('STATISTICS: Reporting every ',$self->{STATISTICS_INTERVAL},' seconds, detail=',$self->{STATISTICS_DETAIL});
  $self->{stats}{START} = time;

  if ( $self->{WATCHDOG_NOTIFICATION_PORT} )
  {
    my $socket = IO::Socket::INET->new(
      Proto     => 'udp',
      LocalPort => $self->{WATCHDOG_NOTIFICATION_PORT},
    );
    $self->Fatal("Could not bind to port $self->{WATCHDOG_NOTIFICATION_PORT} (are you sure the previous watchdog lite  is dead?)") 
    unless $socket;
    $kernel->select_read($socket,'_udp_listen');
  }
}

sub killAgent
{
  my ($self, $kernel, $h) = @_[OBJECT, KERNEL, ARG0];
  my ($agent,$pid,$signal);
  if ( ! $h->{signals} ) { $h->{signals} = [ qw / HUP TERM QUIT CONT KILL KILL / ]; }
  $signal = shift @{$h->{signals}};
  $pid = $h->{PID};
  $agent = $h->{AGENT};

# If the process is dead, there is nothing more to do...
  if ( ! (kill 0 => $pid) )
  {
    delete $self->{AGENTS}{$agent}{pid};
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
  $kernel->delay_set('killAgent',$self->{TIMEOUT},$h);
}


sub _udp_listen
{
  my ($self, $kernel, $socket) = @_[OBJECT, KERNEL, ARG0];
  my ($remote_address,$message);
  my ($agent,$pid,$label,$message_left);

  $message = '';
  $remote_address = recv($socket, $message, DATAGRAM_MAXLEN, 0);

  if ( $message =~ m%^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d: ([^[]+)\[(\d+)\]:\s+(.*)$% )
  {
    $agent = lc($1);
    $pid = $2;
    $message_left = $3;
    return if ( $agent eq lc($self->ME()) );
    if ( $message_left eq 'ping' ) {
      $self->{AGENTS}{$agent}{last_seen} = time();
      $self->{AGENTS}{$agent}{pid} = $pid;
      return;
    }
  }
}

1;

