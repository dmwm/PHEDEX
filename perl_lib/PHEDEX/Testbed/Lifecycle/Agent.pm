package PHEDEX::Testbed::Lifecycle::Agent;
use strict;
use warnings;
use base 'PHEDEX::Core::Agent';
use PHEDEX::Core::JobManager;
use PHEDEX::Core::Loader;
use PHEDEX::Monitoring::Process;
use Time::HiRes;
use File::Path;
use POE;
use JSON::XS;
use Carp;
use Clone qw(clone);
use Data::Dumper;

our @EXPORT = qw( );

our %params =
	(
	  ME			=> 'Lifecycle',
	  LIFECYCLE_CONFIG	=> undef,
	  LIFECYCLE_COMPONENT	=> 'Lifecycle::Lite',
	  STATISTICS_INTERVAL	=> 3600,
	  STATISTICS_DETAIL	=>    1,
	  StatsFrequency	=>  600,
	  Incarnation		=>    0,
	  Jitter		=>    0,
	  CycleSpeedup		=>    1,
	  GarbageCycle		=>    0,
	  GarbageAge		=> 3600,
	  Sequence		=>    1,
	  NJobs			=>    2,
	  MonitorAgentSize	=>    0,
	  MonitorPayloadSize	=>    0,
	  ConfigRefresh		=>    3,
# don't touch these...
	  LOAD_DROPBOX		=> 0,
	  LOAD_DROPBOX_WORKDIRS	=> 0,
	  LOAD_DB		=> 0,
	  LOAD_CYCLE		=> 0,
	);

our $pmon;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %args = @_;
  my $self  = $class->SUPER::new(%params,%args);
  $self->{JOBMANAGER} = new PHEDEX::Core::JobManager(
	NJOBS	=> $self->{NJobs},
	VERBOSE => 0,
	DEBUG	=> 0,
	KEEPALIVE => 5);

  $self->{_njobs} = 0; # for UA-based stuff
  $self->{nWorkflows} = 0;

# Start a POE session for myself

  POE::Session->create (
    object_states =>
    [
      $self =>
      {
        _make_stats         => '_make_stats',

        _start   => '_start',
        _stop    => '_stop',
        _child   => '_child',
        _default => '_default',
      },
    ],
  );

  $pmon = PHEDEX::Monitoring::Process->new();

  bless $self, $class;
  return $self;
}

sub AUTOLOAD {
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

sub Dbgmsg { my $self = shift; $self->SUPER::Dbgmsg(@_) if $self->{Debug}; }

sub OnConnect
{
  my ( $self, $heap, $kernel ) = @_[ OBJECT, HEAP, KERNEL ];

# Only start the timer first time round, or there will be one timer per time
# the receiver is restarted
  return 0 if $heap->{count};
  print "OnConnect: self=$self, heap=$heap\n";

  return 0;
}

sub _default {
  my $self = shift;

  if ( $self->can('poe_default') ) {
    $self->poe_default(@_);
    return;
  }
  PHEDEX::Core::Agent::_default(@_);
}

#-------------------------------------------------------------------------------
sub Log
{
  my $self = shift;
  my $sender = $self->{SENDER};
  if ( $sender ) { $sender->Send(@_); }
  else
  {
    $Data::Dumper::Terse=1;
    $Data::Dumper::Indent=0;
    my $a = Data::Dumper->Dump([\@_]);
    $a =~ s%\n%%g;
    $a =~ s%\s\s+% %g;
    $self->Logmsg($a);
  }
}

#-------------------------------------------------------------------------------
sub _start {
# This sets up the basic state-machinery.
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];

  $kernel->alias_set( $self->{ME} );

# Declare the injection and other states.
# Start watching my configuration file. Things don't actually get rolling until
# the configuration file is read, so yield to that at the end.
  $kernel->state('poe_default', $self);
  $kernel->state(  'nextEvent', $self );
  $kernel->state(  'lifecycle', $self );
  $kernel->state(     'reaper', $self );

  $kernel->state(      'stats', $self );

  $kernel->state(    'garbage', $self );
  $kernel->delay_set('garbage', $self->{GarbageCycle}) if $self->{GarbageCycle};

  $kernel->state(     '_child', $self );
  $kernel->state(      '_stop', $self );

  $kernel->state( 'FileChanged', $self );
  my %watcher_args = (	File     => $self->{LIFECYCLE_CONFIG},
                	Interval => 7,
			Client	 => $self->{ME},
                	Event    => 'FileChanged',
              	     );
  $self->{Watcher} = T0::FileWatcher->new( %watcher_args );
  $kernel->yield('FileChanged');
}

sub _child {}
sub stop { exit(0); }

sub Config { return (shift)->{LIFECYCLE_CONFIG}; }

our $uuid=0;
sub nextEvent {
  my ($self,$kernel,$payload) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($workflow,$cmd,$module,$event,$delay,$id,$msg);
  $workflow = $payload->{workflow};

  if ( $self->{MonitorWorkflowSize} ) {
    if ( ! $payload->{UUID} ) {
      $payload->{UUID} = $workflow->{Name} . ':' . $uuid++;
      PHEDEX::Monitoring::Process::MonitorSize($payload->{UUID},$payload);
    }
  }

  $self->processStats($payload);
  $self->processReport($payload);

  $msg = "nextEvent: $workflow->{Name}:";
  if ( $id = $payload->{id} ) { $msg .= ' ' . $id; }
  $event = shift(@{$payload->{workflow}->{Events}});
  if ( !$event )
  {
    $self->Logmsg("$msg cycle ends") if $self->{Verbose};
    $self->{_states}{cycle_end}{$id} = time;

    if ( $self->{MonitorWorkflowSize} ) {
      $self->Logmsg("Monitoring: final size of $payload->{UUID}: " .
		    PHEDEX::Monitoring::Process::total_size($payload->{UUID}));
      PHEDEX::Monitoring::Process::MonitorSize($payload->{UUID});
    }
    undef $payload;

    $self->{nWorkflows}--;
    $self->Logmsg("$self->{nWorkflows} remaining workflows");
    return;
  } 

  $workflow->{Event} = $event;
  $delay = $workflow->{Intervals}{$event};
  my $txt = join(', ',@{$payload->{workflow}->{Events}});
  if ( !$delay ) {
    $self->Dbgmsg("$msg $event (now) $txt");
    $kernel->yield($event,$payload);
    return;
  }
  if ( $workflow->{Jitter} ) { $delay *= ( 1 + rand($workflow->{Jitter}) ); }
  if ( $self->{CycleSpeedup} ) { $delay /= $self->{CycleSpeedup}; }
  $self->Dbgmsg("$msg $event $delay. $txt");
  $kernel->delay_set($event,$delay,$payload);
}
 
sub FileChanged {
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];
  $self->Logmsg("\"",$self->{LIFECYCLE_CONFIG},"\" has changed...");
  $self->ReadConfig();

  $kernel->alarm_remove($self->{_stats_timer}) if $self->{_stats_timer};
  $self->{_stats_timer} = $kernel->delay_set('stats',$self->{StatsFrequency});

  if ( $self->{Suspend} ) {
    $self->Logmsg("I am suspended, will not start new workflows");
    return;
  }

  if ( $self->{JOBMANAGER}{NJOBS} != $self->{NJobs} ) {
    $self->{JOBMANAGER}{NJOBS} = $self->{NJobs};
  }
 
  if ( $self->{MonitorAgentSize} || $self->{MonitorWorkflowSize} ) {
    eval("require Devel::Size");
    if ( $@ ) {
      my $msg = $self->{MonitorAgentSize} ? 'MonitorAgentSize' : '';
      $msg .= $self->{MonitorWorkflowSize} ? ( $msg ? ' and ' : '' ) . 'MonitorWorkflowSize' : '';
      $self->Fatal("Failed to load Devel::Size. Either remove $msg from your configuration or adjust your PERL5LIB");
    }
  }

  if ( $self->{MonitorAgentSize} ) {
    PHEDEX::Monitoring::Process::MonitorSize('Lifecycle',$self);
    PHEDEX::Monitoring::Process::MonitorSize('POE::Kernel',$kernel);
    PHEDEX::Monitoring::Process::MonitorSize('Lifecycle session',$session);
  }

  $self->Logmsg("Beginning new cycle...");
  my ($workflow,$nWorkflows);
  $nWorkflows = 0;
  foreach ( @{$self->{Workflows}} )
  {
    $workflow = clone($_);
    if ( $workflow->{Suspend} ) {
      $self->Logmsg("Skip lifecycle for \"$workflow->{Name}\" (suspended)");
      next;
    }
    next if ( $workflow->{Incarnations} &&
	      $workflow->{Incarnations} < $workflow->{Incarnation} );
    $self->Logmsg("Beginning lifecycle for \"$workflow->{Name}...\"");
    $kernel->delay_set('lifecycle',0.01,$workflow);
    $nWorkflows++;
  }
  $self->{nWorkflows} += $nWorkflows;
  $self->Logmsg("Started $nWorkflows workflows ($self->{nWorkflows} now running)");

# TW How do I stop myself?
  if ( !$self->{nWorkflows} && $self->{StopOnIdle} ) {
    $kernel->yield('_stop');
    $self->Logmsg("No workflows running, will now exit gracefully");
  }
}

sub id {
  my $self = shift;
  return sprintf('%08x',$self->{Sequence}++);
}

sub lifecycle {
  my ($self,$kernel,$workflow) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($event,$delay,@events);

  return unless $self->{Incarnation} == $workflow->{Incarnation};

  if ( !$workflow->{NCycles} )
  {

    $self->Logmsg("Reached maximum number of cycles for ",$workflow->{Name},", will not start another cycle...");
# TW Do I need this here?
#    $self->{JOBMANAGER}{KEEPALIVE} = 0;
#    $self->{Watcher}->RemoveClient( $self->{ME} ) if defined($self->{Watcher});
    return;
  }
  $workflow->{NCycles}-- if $workflow->{NCycles} > 0;

  my $payload = {
		  'workflow' => $workflow,
		  'id'       => $self->id(),
		  'step'     => 0,
		};
  $self->Dbgmsg("lifecycle: yield nextEvent: ",$workflow->{Name},':',$payload->{id});
  $kernel->yield('nextEvent',$payload);
  $self->{nWorkflows}++;

  $event = $workflow->{Events}->[0];
  return unless $event;
  $delay = $workflow->{CycleTime};
  return unless $delay;
  if ( $self->{Jitter} ) { $delay *= ( 1 + rand($self->{Jitter}) ); }
  if ( $self->{CycleSpeedup} ) { $delay /= $self->{CycleSpeedup}; }
  $self->Dbgmsg("lifecycle: delay=$delay for next \"$workflow->{Name}\"");
  $self->Logmsg("lifecycle: delay($delay) lifecycle");
  $kernel->delay_set('lifecycle',$delay,clone($workflow)) if $delay;
}

sub ReadConfig {
  my $self = shift;
  my ($workflow,@required,$file,$hash,$param,$key,$template,$event);
  $file = shift || $self->{LIFECYCLE_CONFIG};
  $hash = $self->{LIFECYCLE_COMPONENT};
  return unless $file;
  $self->{Name} = $hash unless $self->{Name};
  T0::Util::ReadConfig($self,$hash,$file);

# Sanitise the object, setting defaults etc
  $self->{Defaults}  = {} unless $self->{Defaults};
  $self->{Templates} = {} unless $self->{Templates};
  $self->{Incarnation}++; # This is used to allow old stuff to die out
# Set global default for the case it was missing in the configuration: 
  $self->{CycleTime} = 600 unless defined $self->{CycleTime};
  if ( defined($self->{TmpDir}) ) {
    $self->{TmpDir} =~ s%/$%%;
    $self->{TmpDir} .= '/';
  } else {
    $self->{TmpDir}    = '/tmp/' . (getpwuid($<))[0] . '/';
  }
  foreach ( qw/ Suspend KeepLogs KeepInputs KeepOutputs / ) {
    $self->{$_} = 0 unless defined $self->{$_};
  }
  foreach ( qw/ KeepFailedInputs KeepFailedOutputs KeepFailedLogs / ) {
    $self->{$_} = 1 unless defined $self->{$_};
  }

  push @required, @{$self->{Required}} if $self->{Required};
  push @required, qw / CycleTime NCycles Events Name Suspend TmpDir
                   KeepInputs KeepOutputs KeepLogs
		   KeepFailedInputs KeepFailedOutputs KeepFailedLogs
		   Jitter TmpDir /;

# Fill out the Templates using global defaults, hard-coded. This is just an
# easy way to save typing in the template.
  foreach $key ( keys %{$self->{Templates}} ) {
    $template = $self->{Templates}{$key};
    if ( ! $template->{Events} ) {
      $self->Logmsg("Set default Events $key\n");
      $template->{Events} = [ $key ];
    }
  }

# Fill out the Templates, using the Defaults. This is mostly useful for actions
# that are shared across several templates, to specify what script to call, or
# other parameters for them
  foreach $template ( values %{$self->{Templates}} ) {
    foreach $param ( qw/ Intervals Exec Module / ) {
      $template->{$param} = {}  unless defined $template->{$param};
      foreach $event ( @{$template->{Events}} ) {
        $template->{$param}{$event} = $self->{Defaults}{$param}{$event}
		 unless defined $template->{$param}{$event};
      }
    }
    foreach $event ( @{$template->{Events}} ) {
      if ( !defined $template->{Module}{$event} &&
           !defined $template->{Exec}{$event} ) {
        $self->Fatal("Missing Module/Exec for $event\n");
      }
    }
  }

# Fill out the workflows, using the Templates and then the Defaults
  foreach $workflow ( @{$self->{Workflows}} ) {
    $workflow->{Incarnation} = $self->{Incarnation};
    $self->Logmsg("Setting workflow defaults: \"$workflow->{Name}\"");
    if ( !$workflow->{Template} ) { $workflow->{Template} = $workflow->{Name}; }
    if ( ! defined($self->{Templates}{$workflow->{Template}}) ) {
      $self->Fatal("No Template for workflow \"$workflow->{Template}\"");
    }

#   Workflow defaults fill in for undefined values
    $template = $self->{Templates}{$workflow->{Template}};
    foreach ( keys %{$template} ) {
      if ( !defined( $workflow->{$_} ) )
      {
        $self->Logmsg("Setting default for \"$workflow->{Name}($_)\"") if $self->{Verbose};
        $workflow->{$_} = clone $template->{$_};
      }
    }

#   Global defaults fill in for everything else
    foreach ( keys %{$self->{Defaults}} ) {
      if ( !defined( $workflow->{$_} ) )
      {
        $self->Logmsg("Setting default for \"$workflow->{Name}($_)\"") if $self->{Verbose};
        $workflow->{$_} = clone $self->{Defaults}{$_};
      }
    }

#   Fill in global defaults for undefined dataset defaults 
    foreach ( @required ) {
      if ( !defined( $workflow->{$_} ) )
      {
        $workflow->{$_} = clone $self->{$_};
        $self->Fatal("\"$_\" is undefined for workflow \"$workflow->{Name}\", even at global scope\n") unless defined $workflow->{$_};
      }
    }
  }

  no strict 'refs';
  $self->Log( \%{$self->{LIFECYCLE_COMPONENT}} );

  if ( defined($self->{Watcher}) ) {
    $self->{Watcher}->Interval($self->ConfigRefresh);
  }
}

sub _stop {
  my ( $self, $kernel, $session, $force ) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];

  $self->Logmsg('nothing left to do, may as well shoot myself');
  $self->{Watcher}->RemoveClient( $self->{ME} ) if defined($self->{Watcher});
  $kernel->call($session,'stats');
  $kernel->delay('stats');
  $kernel->delay('garbage');
  $self->{JOBMANAGER}{KEEPALIVE} = 0;
  if ( $self->{Debug} )
  {
    $self->Logmsg('Dumping final state to stdout or to logger');
    $self->Logmsg( $self );
  }
  $self->Logmsg("Wait for JobManager to become idle, then exit...");
}

sub stats {
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($stats,$event,$key,$value);
  $stats = $self->{stats};
  $self->Logmsg("Statistics: ",Dumper($stats));
  $self->Logmsg("Statistics: memory/CPU use: ",$pmon->FormatStats($pmon->ReadProcessStats));

  $self->Logmsg("Statistics: agent & objects: ",$pmon->TotalSizes());
  $self->Dbgmsg("JobManager: Queued:",$self->{JOBMANAGER}->jobsQueued,", Running:",$self->{JOBMANAGER}->jobsRunning());
  return unless $kernel;
  $kernel->delay_set('stats',$self->{StatsFrequency});
}

sub garbage {
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($age,$now,$tmp);
  $now = time();
  $tmp = $self->{TmpDir};
  foreach ( glob("$tmp/*") ) {
    print "Examine $_\n";
    $age = $now - (stat($_))[9];
    if ( $age > $self->{GarbageAge} ) {
      print "$_ is garbage\n";
      unlink $_;
    }
  }
  $kernel->delay_set('garbage',$self->{GarbageCycle});
}

sub register {
  my ($self,$callback,$handler) = @_;
  return if $self->{_registered}{$callback}++;
  $handler = $callback unless $handler;
  $poe_kernel->state($callback,$self,$handler);
}

sub poe_default {
  my ($self,$kernel,$session,$event,$arg1) = @_[ OBJECT, KERNEL, SESSION, ARG0, ARG1 ];
  my ($payload,$workflow,$module,$namespace,$loader,$object);
  $payload = $arg1->[0];
  $workflow = $payload->{workflow};

  if ( !$workflow->{Exec}{$event}  &&
       !$workflow->{Module}{$event} ) {
    if ( $self->{Defaults}{Module}{$event} ) {
      $workflow->{Module}{$event} = $self->{Defaults}{Module}{$event};
    }
    if ( $self->{Defaults}{Exec}{$event} ) {
      $workflow->{Exec}{$event} = clone $self->{Defaults}{Exec}{$event};
    }
  }

  if ( $workflow->{Exec}{$event} ) {
    $self->register($event,'exec');
    $self->Dbgmsg("yield $event");
    $kernel->yield( $event, $payload );
    return;
  }

  if ( $workflow->{Module}{$event} ) {
    $namespace = $workflow->{Namespace};
    if ( !($loader = $self->{LOADER}{$namespace}) ) {
      $loader = $self->{LOADER}{$namespace} = PHEDEX::Core::Loader->new( NAMESPACE => $namespace );
    }
    eval {
      $module = $loader->Load($workflow->{Module}{$event});
    };
    $self->Fatal('load module: ',$@) if $@;
    eval {
      $object = $module->new($self,$workflow);
    };
    $self->Fatal('create module: ',$@) if $@;

#   Sanity check
    if ( !$object->can($event) ) {
      $self->Fatal("Cannot find a \"$event\" function in $module");
    }
    $kernel->state( $event, $object );
    $self->Dbgmsg("call $event");
    $kernel->yield( $event, $payload );
    return;
  }

  $self->Fatal("\"$workflow->{Name}\": no Module or Exec for \"$event\", cannot invoke!\n");
}

our $_uniqueCounter = 0;
our $_uniqueCounterMax = 16*16*16*16*16*16;
sub tmpFile {
  my ($self,$payload,$me) = @_;
  my ($tmp,$workflow);
  $workflow = $payload->{workflow};
  $me = $self->{ME} unless $me;
  $tmp = sprintf($workflow->{TmpDir} . '/Lifecycle-%02x-%s-%s-%s-%06x.',
                $self->{Incarnation},
                $workflow->{Name},
                $workflow->{Event},
                $payload->{id},
                $_uniqueCounter++);
  $_uniqueCounter = 0 if $_uniqueCounter >= $_uniqueCounterMax;
  $tmp =~ s% %_%g;
  $tmp =~ s%//+%/%g;
  return $tmp;
}

sub exec {
  my ($self,$session,$kernel,$event,$payload) = @_[ OBJECT, SESSION, KERNEL, STATE, ARG0 ];
  my ($workflow,$cmd,@cmd,$json,$postback,$in,$out,$log,$tmp,$timeout);
  $workflow = $payload->{workflow};
  $cmd = $workflow->{Exec}{$event};
  $self->Fatal("No command for $event\n") unless $cmd;

  $tmp = $workflow->{TmpDir};
  if ( ! -d $tmp ) {
    mkpath($tmp) || $self->Fatal("Cannot mkdir $tmp: $!\n");
  }
  $tmp = $self->tmpFile($payload);
  ($in,$out,$log) = map { $tmp . $_ } ( 'in', 'out', 'log' );
  @cmd = split(' ',$cmd);
  push @cmd, ('--in',$in,'--out',$out);
  $json = encode_json($payload);
  open IN, ">$in" or $self->Fatal("open $in: $!\n");
  print IN $json;
  close IN;
  $postback = $session->postback('reaper',$payload,$in,$out,$log);
  $timeout = $workflow->{Timeout} || 999;
  $self->{JOBMANAGER}->addJob( $postback, { TIMEOUT=>$timeout, KEEP_OUTPUT=>1, LOGFILE=>$log }, @cmd);
}

sub post_exec {
  my ($self, $arg0, $arg1) = @_;
  my ($workflow,$payload,$in,$out,$log,$json,$result,$name,$id,$event);
  my ($job,$duration,$status,$delay,$report,$stats);

  ($payload,$in,$out,$log) = @{$arg0};
  $workflow = $payload->{workflow};
  $name  = $workflow->{Name};
  $event = $workflow->{Event};
  $id    = $payload->{id};

  $job = $arg1->[0];
  $duration = $job->{DURATION};
  $status   = $job->{STATUS_CODE};
  foreach ( split("\n",$job->{STDOUT}) ) {
    $self->Logmsg("$name:$event:$id:STDOUT $_\n");
  }
  foreach ( split("\n",$job->{STDERR}) ) {
    $self->Logmsg("$name:$event:$id:STDERR $_\n");
  }

# Harvest the output before cleaning it!
  if ( -f $out ) {
    open OUT, "<$out" || $self->Fatal("open $out $!\n");
    $json = <OUT>;
    close OUT;
    $result = decode_json($json);
  } else {
    $result = $payload;
  }

# Clean up
  if ( $status ) {
    $self->Alert("$name:$id status=$status, abandoning...\n");
    if ( -f $in && !$workflow->{KeepFailedInputs} ) {
      unlink $in or $self->Fatal("Could not unlink $in: $!\n");
    } else { $result->{in} = $in; }
    if ( -f $log && !$workflow->{KeepFailedLogs} ) {
      unlink $log or $self->Fatal("Could not unlink $log: $!\n");
    } else { $result->{log} = $log; }
    if ( -f $out && !$workflow->{KeepFailedOutputs} ) {
      unlink $out or $self->Fatal("Could not unlink $out: $!\n");
    } else { $result->{out} = $out; }
  }
  if ( -f $in && !$workflow->{KeepInputs} ) {
    unlink $in or $self->Fatal("Could not unlink $in: $!\n");
  }
  if ( -f $log && !$workflow->{KeepLogs} ) {
    unlink $log or $self->Fatal("Could not unlink $log: $!\n");
  }
  if ( -f $out && !$workflow->{KeepOutputs} ) {
    unlink $out or $self->Fatal("Could not unlink $out: $!\n");
  }

# If there is a 'report' section, act on the information it contains
  if ( ref($result) eq 'HASH' ) {
    $self->processReport($result);
  }

# Global statistics
  $self->{stats}{events}{$name}{$event}{status}{$status}++;
  $self->{stats}{events}{$name}{$event}{count}++;

# If there is a 'stats' section, act on the information it contains
  if ( ref($result) eq 'HASH' ) {
    $self->processStats($result);
  }
  return $result
}

sub processStats {
  my ($self,$payload) = @_;
  my ($stats,$name,$key,$value,$skey);
  return unless $stats = $payload->{stats};

  $name = $payload->{workflow}{Name};
  while ( ($key,$value) = each( %{$stats} ) ) {
    if ( !$self->{stats}{$name}{$key} ) { $self->{stats}{$name}{$key} = {}; }
    $skey = $self->{stats}{$name}{$key};
    if ( ! $skey->{count} ) {
      $skey->{count} = $skey->{total} = 0;
      $skey->{min} = $skey->{max} = $value;
    }
    $skey->{total} += $value;
    $skey->{count}++;
    $skey->{mean} = $skey->{total} / $skey->{count};
    if ( $skey->{min} > $value ) { $skey->{min} = $value; }
    if ( $skey->{max} < $value ) { $skey->{max} = $value; }
  }
  delete $payload->{stats};
}

sub processReport {
  my ($self,$payload) = @_;
  my ($report,$name,$id,$status,$reason,$msg,$msgExtra);
  return unless $report = $payload->{report};

  $name = $payload->{workflow}{Name};
  $id   = $payload->{id};

  if ( $report = $payload->{report} ) {
    $status = lc $report->{status};
    $reason = $report->{reason} || 'none given';
    $msg = "$name:$id status=$status, reason=$reason";
    if ( $report->{in} ) {
      $msgExtra = "in=$report->{in}";
    }
    if ( $report->{out} ) {
      $msgExtra .= ', ' if $msgExtra;
      $msgExtra .= "out=$report->{out}";
    }
    if ( $report->{log} ) {
      $msgExtra .= ', ' if $msgExtra;
      $msgExtra .= "log=$report->{log}";
    }
    if ( $msgExtra ) {
      $msg .= ' (' . $msgExtra . ' )';
    }
    if    ( $status eq 'fatal' ) { $self->Fatal($msg,', Abandoning...'); }
    elsif ( $status eq 'error' ) { $self->Alert($msg); }
    elsif ( $status eq 'warn'  ) { $self->Warn($msg);  }
    elsif ( $status eq 'info'  ) { $self->Logmsg($msg); }
#   elsif ( $status eq 'OK'    ) { } # NOP!
  }
  delete $payload->{report};
}

sub reaper {
  my ($self,$kernel,$session,$arg0,$arg1) = @_[OBJECT,KERNEL,SESSION,ARG0,ARG1];
  my ($workflow,$payload,$in,$out,$log,$result,$delay);

  $result = $self->post_exec($arg0,$arg1);
  ($payload,$in,$out,$log) = @{$arg0};
  $workflow = $payload->{workflow};

# Specific to the 'exec' handler...
  $result = $payload unless $result;
  if ( ref($result) eq 'ARRAY' ) {
    $delay = 0;
    foreach $payload ( @{$result} ) {
      $payload->{parent_id} = $payload->{id};
      $payload->{id} = $self->id();
      delete $payload->{UUID};
      $self->Dbgmsg("lifecycle: yield nextEvent: ",$workflow->{Name},':',$payload->{id});
      $kernel->delay_set('nextEvent',$delay,$payload);
      $delay += 0.05;
    }
  } else {
    $self->Dbgmsg("lifecycle: yield nextEvent: ",$workflow->{Name},':',$payload->{id});
    $kernel->yield('nextEvent',$result);
  }
}

sub post_push {
  my ($self,$event,$payload) = @_;
  my ($post,@events);
  return unless $post = $self->{$event};
  return unless $post->{addEvents};
  return unless @events = @{$post->{addEvents}};
  foreach ( @events ) {
    push @{$payload->{workflow}->{Events}}, $_;
  }
}

sub post_unshift {
  my ($self,$event,$payload) = @_;
  my ($post,@events);
  return unless $post = $self->{$event};
  return unless $post->{prependEvents};
  return unless @events = @{$post->{prependEvents}};
  foreach ( @events ) {
    unshift @{$payload->{workflow}->{Events}}, $_;
  }
}

1;
