package PHEDEX::Core::Config::FactoryLite;

use strict;
use warnings;
use base 'PHEDEX::Core::AgentLite', 'PHEDEX::Core::Logging';
use POE;
use PHEDEX::Core::Timing;
use PHEDEX::Core::JobManager;
use PHEDEX::Core::Loader;
use IO::Socket::INET;
use constant DATAGRAM_MAXLEN => 1024*1024;

our %params =
	(
          ME            => 'WatchdogLite',
	  WAITTIME	=> 90 + rand(3),	# This agent cycle time
	  VERBOSE	=> $ENV{PHEDEX_VERBOSE} || 0,
	  DEBUG		=> $ENV{PHEDEX_DEBUG} || 0,
	  NODAEMON	=> 1,			# Don't daemonise by default!
	  REALLY_NODAEMON=> 0,			# Do daemonise eventually!

	  LAST_SEEN_ALERT	=> 60*120,	# send alerts & restart after this much inactivity
	  LAST_SEEN_WARNING	=> 60*75,	# send warnings after this much inactivity
	  LAST_REPORTED_INTERVAL=> 60*15,	# interval between 'is deliberately down' repeats
	  RETRY_BACKOFF_COUNT	=> 3,		# number of times to try starting agent before backing off
	  RETRY_BACKOFF_INTERVAL=> 3600,	# back off this long before attempting to restart the agent again
	  TIMEOUT		=> 11,		# interval between signals

	  STATISTICS_INTERVAL	=> 3600*12,	# My own reporting frequency
	  STATISTICS_DETAIL	=>    0,	# reporting level: 0, 1, or 2
          LOAD_DROPBOX          => 0,     # Load Dropbox module
          LOAD_CYCLE            => 1,     # Load Cycle module
          LOAD_DB               => 0,     # Load DB module
          STOPFLAG              => 'WatchdogLite',
          WATCHDOG_NOTIFICATION_PORT => 9999,
	);

our @array_params = qw / AGENT_NAMES /;
our @hash_params  = qw / /;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(%params,@_);

  $self->{NOTIFICATION_PORT} = $self->{WATCHDOG_NOTIFICATION_PORT};
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
  my ($Config,$Agent,%Agents,%Modules,$agent);
  $Config = $self->{CONFIGURATION};

  if ( ref($self->{AGENT_LIST}) ne 'ARRAY' )
  { $self->{AGENT_LIST} = [ $self->{AGENT_LIST} ]; }

  foreach $agent ( @{$self->{AGENT_LIST}} )
  {
    $self->Logmsg("Lookup agent \"$agent\"");

    $Agents{$agent}{self} = 1;
  }

# Monitor myself too!
  $Agents{$self->{ME}}{self} = $self;
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

sub idle
{
  my $self = shift;

  my ($agent,$Agent,$Config,$pidfile,$pid,$env,$stopfile);
  my ($now,$last_seen,$last_reported,$mtime);

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
      $stopfile = $env->getExpandedString($Agent->DROPDIR) . 'stop';
      undef $pid;
      if ( $self->{TimesIdle} > 1 ) {
#       We try to catch a missing $pidfile
        if ( -f $pidfile ) {
          if ( open PID, "<$pidfile" ) { 
            $pid = <PID>;
            close PID;
            chomp $pid;
          }
#       then look for the correct pid in AGENT_PID hash, once found, kill agent before something else 
        } else {
          unless ( -f $stopfile ) {
            $self->Alert("Agent=$agent, pid file = $pidfile is gone, looking for pid by other means");
            foreach my $kpid ( keys %{$self->{AGENT_PID}} ) {
            if ( $self->{AGENT_PID}{$kpid} eq $Agent->LABEL ) {
              $self->Alert("Agent=$agent, pid found -> $kpid, killing Agent ...");
    #          POE::Kernel->post($self->{SESSION_ID},'killAgent',{ AGENT => $agent, PID => $kpid });
            }
            }
          }
        }
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
   #       POE::Kernel->post($self->{SESSION_ID},'killAgent',{ AGENT => $agent, PID => $pid });
	}
	elsif ( $last_seen > $self->{LAST_SEEN_WARNING} )
        {
	  $self->Warn("Agent=$agent, PID=$pid, no news for $last_seen seconds");
	}
        next;
      }

#     Now check for a stopfile, which means the agent _should_ be down
      if ( -f $stopfile )
      {
        $last_reported = $self->{AGENTS}{$agent}{last_reported} || 0;
        $last_reported = $now - $last_reported;
        if ( $last_reported > $self->{LAST_REPORTED_INTERVAL} )
        {
          $self->Logmsg("Agent=$agent is down by request, not restarting...");
          $self->{AGENTS}{$agent}{last_reported} = $now;
        }
        next;
      }

#     Agent is down and should not be. Create a jobmanager if I don't have one, and restart the agent
#     Remove records of restarts that are too old to be of interest
      my @starts;
      @starts = sort { $b <=> $a } keys %{$self->{AGENTS}{$agent}{start}};
#     print "Start times for $agent: ",join(', ',@starts)," backoff-count=$self->{RETRY_BACKOFF_COUNT}, backoff-interval=$self->{RETRY_BACKOFF_INTERVAL}\n";
      foreach ( keys %{$self->{AGENTS}{$agent}{start}} )
      {
        if ( $now - $_ > $self->{RETRY_BACKOFF_INTERVAL} ) { delete $self->{AGENTS}{$agent}{start}{$_}; }
      }
#     print "Start times: ",join(', ',@starts),"\n";
      if ( scalar @starts >= $self->{RETRY_BACKOFF_COUNT} )
      {
#	I have reached the backoff-count-limit, and within the window. Do not retry again yet, but let the user know
        if ( !$self->{AGENTS}{$agent}{backoff_reported} )
	{
          my $since = time() - $starts[0];
	  $self->Logmsg("$agent: $self->{RETRY_BACKOFF_COUNT} retries in the last $since seconds. Backing off for $self->{RETRY_BACKOFF_INTERVAL} seconds");
        $self->{AGENTS}{$agent}{backoff_reported}=1;
	}
	next;
      }
  #    $self->startAgent($agent);
    }
    else
    {
#     This is either a session in the current process, or not in my list...
#     $self->Dbgmsg("Agent=$agent, in this process, ignore for now...") if $self->{DEBUG};
    }
  }
  $self->{TimesIdle}++;
}

sub handleJob
{
  my ($self,$agent) = @_;
  $self->Logmsg("$agent started, hopefully...");
  $self->{AGENTS}{$agent}{start}{time()}=1;
  $self->{AGENTS}{$agent}{backoff_reported}=0;
}

sub _poe_init
{
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];
  $kernel->state('_udp_listen', $self);
  $self->Logmsg('STATISTICS: Reporting every ',$self->{STATISTICS_INTERVAL},' seconds, detail=',$self->{STATISTICS_DETAIL});
  $self->{stats}{START} = time;

  if ( $self->{WATCHDOG_NOTIFICATION_PORT} )
  {
    my $socket = IO::Socket::INET->new(
      Proto     => 'udp',
      LocalPort => $self->{WATCHDOG_NOTIFICATION_PORT},
    );
    $self->Fatal("Could not bind to port $self->{WATCHDOG_NOTIFICATION_PORT} (are you sure the previous watchdog lite  is dead?)") unless $socket;
    $kernel->select_read($socket,'_udp_listen');
  }
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
    $agent = $1;
    $pid = $2;
    $message_left = $3;
    return if ( $agent eq $self->ME() );
    print "It's not ME, message from $agent received : $message\n";
    if ( $message_left =~ m%^\s*label=(\S+)$% )
    {
      $label = $1;
      $self->{AGENT_PID}{$pid} = $label;
    }
    $label = $self->{AGENT_PID}{$pid};
    if ( $label )
    {
      $self->{AGENTS}{$label}{last_seen} = time();
      return if ( $message_left eq 'ping' ); # allows contact without flooding the logfile
    }
  }
}

1;

