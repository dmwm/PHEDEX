package PHEDEX::Testbed::Lifecycle::Lite;
use strict;
use warnings;
use base 'PHEDEX::Testbed::Agent', 'PHEDEX::Core::Logging';
use PHEDEX::Core::JobManager;
use PHEDEX::Core::Loader;
use Time::HiRes;
use File::Path;
use POE;
use JSON::XS;
use Carp;
use Data::Dumper;

our @EXPORT = qw( );

our %params =
	(
	  ME			=> 'Lifecycle',
	  LIFECYCLE_CONFIG	=> undef,
	  LIFECYCLE_COMPONENT	=> 'Lifecycle::Lite',
	  StatsFrequency	=> 60,
	  Incarnation		=> 0,
	  Jitter		=> 0,
	  CycleSpeedup		=> 1,
	  GarbageCycle		=> 300,
	  Sequence		=> 1,
	  NJobs			=> 2,
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new(%params,@_);
  $self->{JOBMANAGER} = new PHEDEX::Core::JobManager(
	NJOBS	=> $self->{NJobs},
	VERBOSE => 0,
	DEBUG	=> 0,
	KEEPALIVE => 5);
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

#-------------------------------------------------------------------------------
sub _poe_init
{
# This sets up the basic state-machinery.
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];

  $kernel->alias_set( $self->{ME} );

# Declare the injection and other states. Set the stats counter to fire, and
# start watching my configuration file. Things don't actually get rolling until
# the configuration file is read, so yield to that at the end.
  $kernel->state('poe_default', $self);
  $kernel->state(  'nextEvent', $self );
  $kernel->state(  'lifecycle', $self );
  $kernel->state(     'reaper', $self );

  $kernel->state(      'stats', $self );
  $kernel->delay_set('stats',$self->{StatsFrequency});

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

sub deep_copy {
  my $this = shift;
  if (not ref $this) {
    $this;
  } elsif (ref $this eq "ARRAY") {
    [map deep_copy($_), @$this];
  } elsif (ref $this eq "HASH") {
    +{map { $_ => deep_copy($this->{$_}) } keys %$this};
  } else { die "what type is $_?" }
}

sub nextEvent
{
  my ($self,$kernel,$payload) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($workflow,$cmd,$module,$event,$delay,$id,$msg);

  $workflow = $payload->{workflow};
  $msg = "nextEvent: $workflow->{Name}:";
  if ( $id = $payload->{id} ) { $msg .= ' ' . $id; }
  $event = shift(@{$payload->{events}});
  if ( !$event )
  {
    $self->Logmsg("$msg cycle ends") if $self->{Verbose};
    $self->{_states}{cycle_end}{$id} = time;
    return;
  } 

  $delay = $workflow->{Intervals}{$event};
  my $txt = join(', ',@{$payload->{events}});
  if ( !$delay ) {
    $self->Dbgmsg("$msg $event (now) $txt") if $self->{Debug};
    $kernel->yield($event,$payload);
    return;
  }
  if ( $self->{Jitter} ) { $delay *= ( 1 + rand($self->{Jitter}) ); }
  if ( $self->{CycleSpeedup} ) { $delay /= $self->{CycleSpeedup}; }
  $self->Dbgmsg("$msg $event $delay. $txt") if $self->{Debug};
  $kernel->delay_set($event,$delay,$payload);
}
 
sub FileChanged
{
  my ($self,$kernel) = @_[ OBJECT, KERNEL ];
  $self->Logmsg("\"",$self->{LIFECYCLE_CONFIG},"\" has changed...");
  $self->ReadConfig();
  return if $self->{Suspend};

  if ( $self->{JOBMANAGER}{NJOBS} != $self->{NJobs} ) {
    $self->{JOBMANAGER}{NJOBS} = $self->{NJobs};
  }
 
  $self->Logmsg("Beginning new cycle...");
  my ($workflow,$nWorkflows);
  $nWorkflows = 0;
  foreach $workflow ( @{$self->{Workflows}} )
  {
    next if $workflow->{Suspend};
    $self->Logmsg("Beginning lifecycle for \"$workflow->{Name}...\"");
    $kernel->delay_set('lifecycle',0.01,$workflow);
    $nWorkflows++;
  }
  $self->Logmsg("Started $nWorkflows workflows");
  return if $nWorkflows;
  if ( $self->{StopOnIdle} ) {
    $kernel->yield('_stop');
    $self->Logmsg("No workflows started, will now exit gracefully");
  }
}

sub id
{
  my $self = shift;
  return sprintf('%08x',$self->{Sequence}++);
}

sub lifecycle
{
  my ($self,$kernel,$workflow) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($event,$delay,@events);
  return unless $self->{Incarnation} == $workflow->{Incarnation};

  push @events, @{$workflow->{events}};
  if ( !$workflow->{NCycles} )
  {

    $self->Logmsg("Maximum number of cycles executed, stopping...");
    $self->{JOBMANAGER}{KEEPALIVE} = 0;
    $self->{Watcher}->RemoveClient( $self->{ME} ) if defined($self->{Watcher});
    return;
  }
  $workflow->{NCycles}-- if $workflow->{NCycles} > 0;

  my $payload = {
		  'workflow' => $workflow,
		  'events'   => [@events],
		  'id'       => $self->id(),
		};
  $self->Logmsg("lifecycle: yield nextEvent") if $self->{Debug};
  $kernel->yield('nextEvent',$payload);

  $event = $events[0];
  return unless $event;
  $delay = $workflow->{CycleTime};
  return unless $delay;
  if ( $self->{Jitter} ) { $delay *= ( 1 + rand($self->{Jitter}) ); }
  if ( $self->{CycleSpeedup} ) { $delay /= $self->{CycleSpeedup}; }
  $self->Dbgmsg("lifecycle: delay=$delay for next \"$workflow->{Name}\"") if $self->{Debug};
  $self->Logmsg("lifecycle: delay($delay) lifecycle") if $self->{Debug};
  $kernel->delay_set('lifecycle',$delay,$workflow) if $delay;
}

sub ReadConfig
{
  my $self = shift;
  my ($workflow,@required,$file,$hash,$param,$template,$event);
  $file = shift || $self->{LIFECYCLE_CONFIG};
  $hash = $self->{LIFECYCLE_COMPONENT};
  return unless $file;
  T0::Util::ReadConfig($self,$hash,$file);

# Sanitise the object, setting defaults etc
  $self->{Defaults}  = {} unless $self->{Defaults};
  $self->{Templates} = {} unless $self->{Templates};
  $self->{Incarnation}++; # This is used to allow old stuff to die out
# Set global default for the case it was missing in the configuration: 
  $self->{CycleTime} = 600 unless defined $self->{CycleTime};
  $self->{TmpDir}    = '/tmp/' . (getpwuid($<))[0] . '/';
  foreach ( qw/ Suspend KeepLogs KeepInputs KeepOutputs / ) {
    $self->{$_} = 0 unless defined $self->{$_};
  }
  foreach ( qw/ KeepFailedInputs KeepFailedOutputs KeepFailedLogs / ) {
    $self->{$_} = 1 unless defined $self->{$_};
  }

  push @required, @{$self->{Required}} if $self->{Required};
  push @required, ('CycleTime','NCycles','Events','Name','Suspend','TmpDir',
                   'KeepInputs','KeepOutputs','KeepLogs',
		   'KeepFailedInputs','KeepFailedOutputs','KeepFailedLogs');

# Fill out the Templates, using the Defaults. This is mostly useful for actions
# that are shared across several templates, to specify what script to call, or
# other parameters for them
  foreach $param ( qw/ Intervals Exec Module / ) {
    foreach $template ( values %{$self->{Templates}} ) {
      $template->{$param} = {}  unless defined $template->{$param};
      foreach $event ( @{$template->{Events}} ) {
        $template->{$param}{$event} = $self->{Defaults}{$param}{$event}
		 unless defined $template->{$param}{$event};
      }
    }
  }

# Fill out the workflows, using the Templates and then the Defaults
  foreach $workflow ( @{$self->{Workflows}} ) {
    $workflow->{Incarnation} = $self->{Incarnation};
    push @{$workflow->{events}}, @{$self->{Templates}{$workflow->{Template}}{Events}};

#   Workflow defaults fill in for undefined values
    $template = $self->{Templates}{$workflow->{Template}};
    foreach ( keys %{$template} ) {
      if ( !defined( $workflow->{$_} ) )
      {
        $self->Logmsg("Setting default for \"$workflow->{Name}($_)\"") if $self->{Verbose};
        $workflow->{$_} = $template->{$_};
      }
    }

#   Global defaults fill in for everything else
    foreach ( keys %{$self->{Defaults}} ) {
      if ( !defined( $workflow->{$_} ) )
      {
        $self->Logmsg("Setting default for \"$workflow->{Name}($_)\"") if $self->{Verbose};
        $workflow->{$_} = $self->{Defaults}{$_};
      }
    }


#   Fill in global defaults for undefined dataset defaults 
    foreach ( @required ) {
      if ( !defined( $workflow->{$_} ) )
      {
        $workflow->{$_} = $self->{$_};
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

sub _stop
{
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
    $self->Log( $self );
  }
  $self->Logmsg("Wait for JobManager to become idle, then exit...");
}

sub stats
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($stats,$event,$key,$value);
  $stats = $self->{stats};
  $self->Logmsg("Statistics: ",Dumper($stats));
  return unless $kernel;
  $kernel->delay_set('stats',$self->{StatsFrequency});
}

sub garbage
{
return;
$DB::single=1;
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($now,$blockid);
  $now = time;
  foreach $blockid ( keys %{$self->{_states}{cycle_end}} )
  {
    if ( $now - $self->{_states}{cycle_end}{$blockid} > $self->{GarbageCycle} )
    {
      $self->Logmsg("garbage-collecting block $blockid") if $self->{Debug};
      delete $self->{_states}{cycle_end}{$blockid};
      delete $self->{_states}{$blockid};
    }
  }
  $kernel->delay_set('garbage',$self->{GarbageCycle});
}

sub poe_default {
  my ($self,$kernel,$session,$event,$arg0) = @_[ OBJECT, KERNEL, SESSION, ARG0, ARG1 ];
  my ($payload,$workflow,$module,$namespace,$loader,$object);
  $payload = $arg0->[0];
  $workflow = $payload->{workflow};
  $workflow->{Event} = $event;

  if ( $workflow->{Exec}{$event} ) {
    $kernel->state( $event, $self, 'exec' );
    $self->Dbgmsg("yield $event") if $self->{Debug};
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
    $self->Dbgmsg("call $event") if $self->{Debug};
    $kernel->yield( $event, $payload );
    return;
  }

  $self->Fatal("\"$workflow->{Name}\": no Module or Exec for \"$event\", cannot invoke!\n");
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
  $tmp .= sprintf('/Lifecycle-%02x-%s-%s-%s.',
		$self->{Incarnation},
		$workflow->{Name},
		$event,
		$payload->{id});
  $tmp =~ s% %_%g;
  $in  = $tmp . 'in';
  $out = $tmp . 'out';
  $log = $tmp . 'log';
  @cmd = split(' ',$cmd);
  push @cmd, ('--in',$in,'--out',$out);
  $json = encode_json($payload);
  open IN, ">$in" or $self->Fatal("open $in: $!\n");
  print IN $json;
  close IN;
  $postback = $session->postback('reaper',$workflow,$payload,$in,$out,$log);
  $timeout = $workflow->{Timeout} || 999;
  $self->{JOBMANAGER}->addJob( $postback, { TIMEOUT=>$timeout, KEEP_OUTPUT=>1, LOGFILE=>$log }, @cmd);
}

sub reaper
{
  my ($self, $kernel, $arg0, $arg1) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
  my ($workflow,$payload,$in,$out,$log,$json,$result,$name,$id,$event);
  my ($job,$duration,$status,$delay,$report,$reason,$msg,$stats,$key,$value,$skey);

  ($workflow,$payload,$in,$out,$log) = @{$arg0};
  $name  = $workflow->{Name};
  $event = $workflow->{Event};
  $id    = $payload->{id};

  $job = $arg1->[0];
  $duration = $job->{DURATION};
  $status   = $job->{STATUS_CODE};
  foreach ( split("\n",$job->{STDOUT}) ) {
    $self->Logmsg("$name:$id:STDOUT $_\n");
  }
  foreach ( split("\n",$job->{STDERR}) ) {
    $self->Logmsg("$name:$id:STDERR $_\n");
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
    }
    if ( -f $log && !$workflow->{KeepFailedLogs} ) {
      unlink $log or $self->Fatal("Could not unlink $log: $!\n");
    }
    if ( -f $out && !$workflow->{KeepFailedOutputs} ) {
      unlink $out or $self->Fatal("Could not unlink $out: $!\n");
    }
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
    if ( $report = $result->{report} ) {
      $status = lc $report->{status};
      $reason = $report->{reason} || 'none given';
      $msg = "$name:$id status=$status, reason=$reason. Abandoning...\n";
      if    ( $status eq 'fatal' ) { $self->Fatal($msg); }
      elsif ( $status eq 'error' ) { $self->Alert($msg); }
      elsif ( $status eq 'warn'  ) { $self->Warn($msg);  }
      elsif ( $status eq 'info'  ) { $self->Logmsg($msg); }
#     elsif ( $status eq 'OK'    ) { } # NOP!
    }
    delete $result->{report};
  }

# Global statistics
  $self->{stats}{events}{$name}{$event}{status}{$status}++;
  $self->{stats}{events}{$name}{$event}{count}++;

# If there is a 'stats' section, act on the information it contains
  if ( ref($result) eq 'HASH' ) {
    if ( $stats = $result->{stats} ) {
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
    }
    delete $result->{stats};
  }

  if ( ref($result) eq 'ARRAY' ) {
    $delay = 0;
    foreach $payload ( @{$result} ) {
      $payload->{parent_id} = $payload->{id};
      $payload->{id} = $self->id();
      $self->Dbgmsg("yield nextEvent") if $self->{Debug};
      $kernel->delay_set('nextEvent',$delay,$payload);
      $delay += 0.05;
    }
  } else {
    $self->Dbgmsg("yield nextEvent") if $self->{Debug};
    $kernel->yield('nextEvent',$result);
  }
}

1;
