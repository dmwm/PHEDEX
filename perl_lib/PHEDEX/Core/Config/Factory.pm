package PHEDEX::Core::Config::Factory;

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';
use POE;
use PHEDEX::Core::Timing;
use PHEDEX::Core::JobManager;
use PHEDEX::Core::Loader;
use IO::Socket::INET;
use constant DATAGRAM_MAXLEN => 1024*1024;

$PHEDEX::Core::Factory::rerun = 0;

our %params =
	(
	  MYNODE	=> undef,		# my TMDB nodename
	  ME		=> 'Watchdog',          # Name for the record
	  WAITTIME	=> 90 + rand(3),	# This agent cycle time
	  VERBOSE	=> $ENV{PHEDEX_VERBOSE} || 0,
	  DEBUG		=> $ENV{PHEDEX_DEBUG} || 0,
	  AGENT_LIST	=> undef,		# Which agents am I to start?
	  LIMIT		=> undef,		# Limits to impose on agents' resource use
	  NODAEMON	=> 1,			# Don't daemonise by default!
	  REALLY_NODAEMON=> 0,			# Do daemonise eventually!
	  NJOBS		=> 3,			# start 3 agents at a time

	  LAST_SEEN_ALERT	=> 60*120,	# send alerts & restart after this much inactivity
	  LAST_SEEN_WARNING	=> 60*75,	# send warnings after this much inactivity
	  LAST_REPORTED_INTERVAL=> 60*15,	# interval between 'is deliberately down' repeats
	  RETRY_BACKOFF_COUNT	=> 3,		# number of times to try starting agent before backing off
	  RETRY_BACKOFF_INTERVAL=> 3600,	# back off this long before attempting to restart the agent again
	  TIMEOUT		=> 11,		# interval between signals

	  STATISTICS_INTERVAL	=> 3600*12,	# My own reporting frequency
	  STATISTICS_DETAIL	=>    0,	# reporting level: 0, 1, or 2

          SUMMARY_INTERVAL      => 3600*24,     # Frequency for all agents report status, once everyday
          NOTIFY_PLUGIN         => 'logfile',   # plugin used for reporting 
          REPORT_PLUGIN         => 'summary',   # plugin used to generate report
          WATCHDOG_NOTIFICATION_PORT => 9999,   # Port to listen
	);

our @array_params = qw / AGENT_NAMES /;
our @hash_params  = qw / /;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(%params,@_);

  $self->{_NOTIFICATION_PORT} = $self->{NOTIFICATION_PORT} ||
	$self->{ENVIRONMENT}->getExpandedParameter('PHEDEX_NOTIFICATION_PORT') ||
	$ENV{PHEDEX_NOTIFICATION_PORT};
  die "'PHEDEX_NOTIFICATION_PORT' not set correctly in your configuration file, giving up...\n" unless $self->{_NOTIFICATION_PORT};
  undef $self->{NOTIFICATION_PORT}; # So I don't talk to myself via the logger

  $self->{WATCHDOG_PORT} =
        $self->{ENVIRONMENT}->getExpandedParameter('PHEDEX_WATCHDOG_NOTIFICATION_PORT') ||
        $ENV{PHEDEX_WATCHDOG_NOTIFICATION_PORT} || $self->{WATCHDOG_NOTIFICATION_PORT};
  $self->{WATCHDOG_NOTIFICATION_PORT} = $self->{WATCHDOG_PORT};

# Just prove that I can read the config file safely, before daemonising, so I
# can spit the dummy if the user has screwed up somehow.
  my $Config = PHEDEX::Core::Config->new();
  $Config->readConfig( $self->{CONFIG_FILE} );

  bless $self, $class;
  $self->createLimits();

  $self->{PHEDEX_SITE} = $self->{ENVIRONMENT}->getExpandedParameter('PHEDEX_SITE') ||
        $ENV{PHEDEX_SITE};
  die "'PHEDEX_SITE' not set correctly in your configuration file, giving up...\n" unless $self->{PHEDEX_SITE};

  $self->{SUMMARY_INTERVAL} = $self->{_SUMMARY_INTERVAL} if ( $self->{_SUMMARY_INTERVAL} );
  $self->{REPORT_PLUGIN} = $self->{_REPORT_PLUGIN} if ( $self->{_REPORT_PLUGIN} ); 
  $self->{NOTIFY_PLUGIN} = $self->{_NOTIFY_PLUGIN} if ( $self->{_NOTIFY_PLUGIN} ); 

  $self->{NOTIFY_PLUGIN} = 'Log' if (lc($self->{NOTIFY_PLUGIN}) eq 'logfile' );
  $self->{NOTIFY_PLUGIN} = 'Email' if (lc($self->{NOTIFY_PLUGIN}) eq 'mail' );

  my @notify_reject = ( qw / Template / );
  my @report_reject = ( qw / Template / );

  my $notify_loader = PHEDEX::Core::Loader->new( NAMESPACE => 'PHEDEX::Monitoring::Notify',
                                                 REJECT => \@notify_reject );
  $self->{notify_plug} = $notify_loader->Load( lc($self->{NOTIFY_PLUGIN}) )->new( DEBUG => $self->{DEBUG},
                                                                                  PHEDEX_SITE => $self->{PHEDEX_SITE} );

  my $report_loader = PHEDEX::Core::Loader->new( NAMESPACE => 'PHEDEX::Monitoring::Reports',
                                                 REJECT => \@report_reject );
  $self->{report_plug} = $report_loader->Load( lc($self->{REPORT_PLUGIN}) )->new( DEBUG => $self->{DEBUG} );
  $self->{TimesIdle} = 1;
  $self->{last_db_connect} = time();

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
  foreach ( qw / AGENT_LIST LAST_SEEN_ALERT LAST_SEEN_WARNING TIMEOUT LIMIT / )
  {
    my $val = $config->{OPTIONS}{$_};
    next unless defined($val);
    if ( ref($val) eq 'ARRAY' )
    {
      $self->Logmsg("reloadConfig: set $_=",join(',',@{$val}));
    }
    else
    {
      $self->Logmsg("reloadConfig: set $_=$val");
    }
    $self->{$_} = $val;
  }
  $self->createLimits();
  $self->createAgents();
}

sub createLimits
{
  my $self = shift;
  delete $self->{_limits};
  if ( ref($self->{LIMIT}) ne 'ARRAY' ) {
    $self->{LIMIT} = [ $self->{LIMIT} ];
  }
  foreach ( @{$self->{LIMIT}} )
  {
    my ($re,$key,$val) = split(',',$_);
    next unless $re && $key && $val; # minimal syntax-check!
    $key = lc $key;
    $self->{_limits}{$re}{ $key } = $val;
  }
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
      my @cmd = ($Master,'--nocheckdb','--config',$self->{CONFIG_FILE},'start',$agent);
      $Agents{$agent}{cmd} = \@cmd;
    }
  }

# Monitor myself too!
  $Agents{$self->{ME}}{self} = $self;
  $self->Logmsg('I am running these agents: ',join(', ',sort keys %Agents));
  eval { 
         $self->connectAgent(); 
       };
  $self->rollbackOnError();
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
  $self->watchdog_notify('ping');
  $self->Logmsg('I have successfully become a daemon');
}

sub idle
{
  my $self = shift;

  my ($agent,$Agent,$Config,$pidfile,$pid,$env,$stopfile);
  my ($now,$last_seen,$last_reported,$mtime);

  $now = time();
  if ( ($now - $self->{last_db_connect}) > 30*60 ) {        
     eval { 
            $self->connectAgent(); 
          };
     $self->rollbackOnError();
     $self->{last_db_connect} = $now;
  };
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
      if ( -f $pidfile ) {
        if ( open PID, "<$pidfile" ) { 
          $pid = <PID>;
          close PID;
          chomp $pid;
        }
      }
      if ( ! $pid && ! -f $stopfile ) {
#       No PID and no stopfile. Look for the correct pid in AGENT_PID hash.
#       Once found, kill agent before re-starting it, to be safe
        $self->Logmsg("Agent=$agent, pid file = $pidfile is gone, looking for pid by other means");
        foreach my $kpid ( keys %{$self->{AGENT_PID}} ) {
          if ( $self->{AGENT_PID}{$kpid} eq $Agent->LABEL ) {
            $self->Alert("Agent=$agent, pid found -> $kpid, killing Agent ...");
            POE::Kernel->post($self->{SESSION_ID},'killAgent',{ AGENT => $agent, PID => $kpid });
          }
        }
      }

      if ( $pid && (kill 0 => $pid) ) {
#       There is a process, and it still responds. Consider it 'seen'
        if ( !$self->{AGENT_PID}{$pid} ) { $self->{AGENT_PID}{$pid} = $Agent->LABEL; }
        if ( !$self->{AGENTS}{$agent}{last_seen} ) {
          $self->Logmsg("Agent=$agent, process found, considered alive");
          $self->{AGENTS}{$agent}{last_seen} = $now; 
        }
        $last_seen = $self->{AGENTS}{$agent}{last_seen};
        $last_seen = $now - $last_seen;
        if ( $last_seen > $self->{LAST_SEEN_ALERT} )
        {
	  $self->Alert("Agent=$agent, PID=$pid, no news for $last_seen seconds");
          POE::Kernel->post($self->{SESSION_ID},'killAgent',{ AGENT => $agent, PID => $pid });
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
      $self->startAgent($agent);
    }
    else
    {
#     This is either a session in the current process, or not in my list...
#     $self->Dbgmsg("Agent=$agent, in this process, ignore for now...") if $self->{DEBUG};
    }
  }
  $self->{TimesIdle}++;
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
  $self->{AGENTS}{$agent}{start}{time()}=1;
  $self->{AGENTS}{$agent}{backoff_reported}=0;
# my @starts;
# @starts = sort { $b <=> $a } keys %{$self->{AGENTS}{$agent}{start}};
# print "Started $agent: ",join(', ',@starts),"\n";
}

sub _poe_init
{
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];
  $kernel->state('killAgent', $self);
  $kernel->state('_make_stats', $self);
  $kernel->state('_do_summary', $self);
  $kernel->state('_udp_listen', $self);
  $self->Logmsg('STATISTICS: Reporting every ',$self->{STATISTICS_INTERVAL},' seconds, detail=',$self->{STATISTICS_DETAIL});
  $self->{stats}{START} = time;
  $self->{stats}{maybeStop}=0;
  $kernel->delay_set('_make_stats',$self->{STATISTICS_INTERVAL});
  $kernel->delay_set('_do_summary',$self->{SUMMARY_INTERVAL});

  if ( $self->{_NOTIFICATION_PORT} )
  {
    my $socket = IO::Socket::INET->new(
      Proto     => 'udp',
      LocalPort => $self->{_NOTIFICATION_PORT},
    );
    $self->Fatal("Could not bind to port $self->{_NOTIFICATION_PORT} (are you sure the previous watchdog is dead?)") unless $socket;
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
    $agent = $1;
    $pid = $2;
    $message_left = $3;
    return if ( $agent eq $self->ME() );
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
      if ( $message_left =~ m%^\s*AGENT_STATISTICS (.*)$% )
      {
        $message_left = $1;
        foreach ( split(' ',$message_left) )
        {
          $_ =~ m%^([^=]+)=(.+)$%;
          $self->{AGENTS}{$label}{resources}{ lc($1) } = $2;
        }
      }
      $self->checkAgentLimits($label,$pid);
    }
  }
  $self->watchdog_notify('ping');
  print $message;
}

sub checkAgentLimits
{
  my ($self,$agent,$pid) = @_;
  my ($re,$key,$val);
  foreach $re ( sort keys %{$self->{_limits}} )
  {
    if ( $agent =~ m%$re% )
    {
      foreach $key ( keys %{$self->{_limits}{$re}} )
      {
        if ( !defined($self->{AGENTS}{$agent}{resources}{$key}) ) {
          $self->Alert("Agent=$agent, no resources allocated so far ...");
          return;
        }
        if ( $self->{_limits}{$re}{$key} < $self->{AGENTS}{$agent}{resources}{$key} )
        {
          $self->Alert("Agent=$agent, PID=$pid, resource-use too high ($key=$self->{AGENTS}{$agent}{resources}{$key}), killing...");
          POE::Kernel->post($self->{SESSION_ID},'killAgent',{ AGENT => $agent, PID => $pid });
          return;
        }
      }
    }
  }
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

sub _do_summary {
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];

  my $some_text = $self->{report_plug}->generate_it( AGENTS => $self->{AGENTS} );
  $self->{notify_plug}->send_it($some_text);
 
  $kernel->delay_set('_do_summary',$self->{SUMMARY_INTERVAL});
}

sub watchdog_notify{
  my $self = shift;
  my $port = $self->{NOTIFICATION_PORT};
  $self->{NOTIFICATION_PORT} = $self->{WATCHDOG_NOTIFICATION_PORT};
  $self->Notify(@_);
  $self->{NOTIFICATION_PORT} = $port;
}
1;

