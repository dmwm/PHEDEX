package PHEDEX::Core::Agent;

=head1 NAME

PHEDEX::Core::Agent - POE-based Agent daemon base class

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use POSIX;
use File::Path;
use File::Basename;
use Time::HiRes qw / time /;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;
use PHEDEX::Core::Config;                                                       
use PHEDEX::Monitoring::Process;
use PHEDEX::Core::Loader;
use Data::Dumper;

# %params, %args, config-files...?
# Precedence is: command-line(%args), config-files, %params(default)
# but %params is the definitive source of the list of legal keys, so all keys
# for the agent should be listed here.

=head1 Agent initialisation

Agents can be initialised with default parameters, with parameters from 
Config files, or with command-line arguments. That's also the order of 
precedence, config files override defaults and command-line arguments 
override config files.

Defaults are defined in the %params hash in the agent 
module. The PHEDEX::Core::Agent module has defaults for most of the 
parameters you will ever need, if you have more or different default 
values you need only define them in your own %params hash in your own 
agent.

Getting the precedence-order for setting parameters is not trivial. For
simple scalars it's easy, you need only check if the value is defined on
the command-line, the config file, and the %params hash, and set it from
the first one that defines it. Note that you need to check for defined,
not 'true', in case the default is 0 or false.

For array or hash values, such as IGNORE_NODES, it's more complex. You
can't put a Perl array or hash into a config file, or on the command-line,
but you can put a comma-separated list there. So, the technique is to 
leave the value of such parameters undef in the %params hash and declare 
separately two arrays, @array_params and @hash_params, which hold the 
key-names of the array and hash parameters. When the object is initialised 
(via the C<< init >> method, at the beginning of the C<< process >> method)
the default C<< init >> method will check which parameters are required to be
arrays or hashes and either set them to null arrays/hashes if they are not defined 
or, if they have scalar values, will split the scalar on commas and set 
them from that.

=cut

our %params =
	(
	  ME		=> undef,
	  DBH		=> undef,
	  SHARED_DBH	=> 0,
	  DBCONFIG	=> undef,
	  DROPDIR	=> undef,
	  NEXTDIR	=> undef,
	  INBOX		=> undef,
	  WORKDIR	=> undef,
	  OUTBOX	=> undef,
	  STOPFILE	=> undef,
	  PIDFILE	=> undef,
	  LOGFILE	=> undef,
	  NODES		=> undef,
	  IGNORE_NODES	=> undef,
	  ACCEPT_NODES	=> undef,
	  WAITTIME	=> 7,
	  AUTO_NAP      => 1,
	  JUNK		=> undef,
	  BAD		=> undef,
	  STARTTIME	=> undef,
	  NWORKERS	=> 0,
	  WORKERS	=> undef,
	  CONFIG_FILE	=> $ENV{PHEDEX_CONFIG_FILE},
	  LABEL		=> $ENV{PHEDEX_AGENT_LABEL},
	  ENVIRONMENT	=> undef,
	  AGENT		=> undef,
	  DEBUG         => $ENV{PHEDEX_DEBUG} || 0,
 	  VERBOSE       => $ENV{PHEDEX_VERBOSE} || 0,
	  NOTIFICATION_HOST   => undef,
	  NOTIFICATION_PORT   => undef,
	  _DOINGSOMETHING     => 0,
	  _DONTSTOPME	      => 0,
	  STATISTICS_INTERVAL => 3600,	# reporting frequency
	  STATISTICS_DETAIL   => 1,	# reporting level: 0, 1, or 2
          LOAD_DROPBOX        => 1,     # Load Dropbox module...
          LOAD_DROPBOX_WORKDIRS => 0,   # ...but not all the directories...
          LOAD_CYCLE          => 1,     # Load Cycle module
          LOAD_DB             => 1,     # Load DB module
	);

our (@array_params,@hash_params,@required_params,@writeable_dirs,@writeable_files);
@array_params = qw / STARTTIME /;
@hash_params  = qw / BAD JUNK /;
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = $class->SUPER::new(@_);
    my %p = %params;

    my %args = (@_);
    my $me = $self->AgentType($args{ME});

#   variable to hold plugin modules. Note they are local, we already have make sure that
#   in case of a modules is loaded the given class is store 
    my @agent_module_reject = ( qw / Template Agent AgentLite/ );
    my $agent_module_loader = PHEDEX::Core::Loader->new( NAMESPACE => 'PHEDEX::Core::Agent',
                                                         REJECT    => \@agent_module_reject );

#   Retrieve the agent environment, if I can.
    my ($config,$cfg,$label,$key,$val);
    $config = $args{CONFIG_FILE} || $p{CONFIG_FILE};
    $label = $self->{LABEL} = $args{LABEL} || $p{LABEL} || $me;
    if ( $config && $label )
    {
      $cfg = PHEDEX::Core::Config->new();
      foreach ( split(',',$config) ) { $cfg->readConfig($_); }
      $self->{AGENT} = $cfg->select_agents($label);
      $self->{CONFIGURATION} = $cfg;

#     Is it really an error to not find the agent label in the config file?
      die "Cannot find agent \"$label\" in $config\n"
		unless $self->{AGENT} && ref($self->{AGENT});
      $self->{ENVIRONMENT} = $cfg->ENVIRONMENTS->{$self->{AGENT}->ENVIRON};
      die "Cannot find environment for agent \"$label\" in $config\n"
		unless $self->{ENVIRONMENT};

#     options from the configuration file override the defaults
      while (my ($k,$v) = each %{$self->{AGENT}->{OPTIONS}} )
      {
        $k =~ s%^-+%%;
        $k = uc $k;
#       Historical, mapping command-line option to agent-internal representation
        $k = 'DBCONFIG' if $k eq 'DB';
        $v = $self->{ENVIRONMENT}->getExpandedString($v);
        $p{$k} = $v;
      }

#     Some parameters are derived from the environment
      if ( $self->{AGENT} && $self->{ENVIRONMENT} )
      {
        foreach ( qw / DROPDIR LOGFILE PIDFILE / )
        {
          my $k = $self->{AGENT}->$_();
          $p{$_} = $self->{ENVIRONMENT}->getExpandedString($k);
        }
      }
    }

#   Now set the %args hash, from environment or params if not the command-line
    foreach $key ( keys %p )
    {
      next if defined $args{$key};
      if ( $self->{ENVIRONMENT} )
      {
        $val = $self->{ENVIRONMENT}->getExpandedParameter($key);
        if ( defined($val) )
        {
          $args{$key} = $val;
          next;
        }
      }
      $args{$key} = $p{$key};
    }

    while (my ($k, $v) = each %args)
    { $self->{$k} = $v unless defined $self->{$k}; }

#   ensure parameters (PIDFILE, DROPDIR, LOGFILE, NODAEMON) are coherent
    if ( $args{LOGFILE} ) {
      push @writeable_files,'LOGFILE';
    } else {
      $self->{NODAEMON} = 1;
    }
    if ( $args{DROPDIR} ) {
      $self->{LOAD_DROPBOX} = 1;
      $self->{PIDFILE}  = $args{DROPDIR} . '/pid'  unless $args{PIDFILE};
      $self->{STOPFILE} = $args{DROPDIR} . '/stop' unless $args{STOPFILE};
    } else {
      $self->{LOAD_DROPBOX} = 0;
      $self->{PIDFILE}  = $self->{LABEL} . '.pid'  unless $args{PIDFILE};
      $self->{STOPFILE} = $self->{LABEL} . '.stop' unless $args{STOPFILE};
    }
    push @writeable_files,'PIDFILE';

#   Load the Dropbox modules. _Dropbox subclass is create and attach to self
    if ( $self->{LOAD_DROPBOX} ) {
      my $dropbox_module = $agent_module_loader->Load('Dropbox')->new( $self );
    }

#   Basic validation: Explicitly call the base method to validate only the
#   core agent. This may be called again in the derived agent, to validate
#   other parameters. No harm in that!
    die "$me: Failed validation, exiting\n" if $self->isInvalid();

#   Clean PID and STOP flags. This method is always defined.
    $self->cleanDropbox($me);

#   If required, daemonise, write pid file and redirect output.
    $self->daemon();

#   Load the Cycle modules. _Cycle subclass is create and attach to self
    my $cycle_module = $agent_module_loader->Load('Cycle')->new( $self ) if $self->{LOAD_CYCLE};
     
#   Finally, start some self-monitoring...
    $self->{pmon} = PHEDEX::Monitoring::Process->new();

#   Initialise subclass.
    $self->init();

#   Load the DB modules. _DB subclass is create and attach to self
    if ( $self->{LOAD_DB} ) {
      my $db_module = $agent_module_loader->Load('DB')->new( $self );
    }

#   Validate the object!. This method is always defined.
    die "Agent ",$self->{ME}," failed validation\n" if $self->isInvalid();

#   Announce myself...
    $self->Notify("label=$label");
    $self->Dbgmsg("Agent was loaded DB=>$self->{LOAD_DB}, CYCLE=$self->{LOAD_CYCLE}, DROPBOX=$self->{LOAD_DROPBOX}") if $self->{DEBUG};

    bless $self, $class;
    return $self;
}

sub isInvalid {
  my $self = shift;
  my %h = @_;
  @{$h{REQUIRED}} = @required_params unless $h{REQUIRED};
  @{$h{WRITEABLE_DIRS}}  = @writeable_dirs  unless $h{WRITEABLE_DIRS};
  @{$h{WRITEABLE_FILES}} = @writeable_files unless $h{WRITEABLE_FILES};

  my $errors = 0;
  foreach ( @{$h{REQUIRED}} )
  {
   next if defined $self->{$_};
    $errors++;
    $self->Warn("Required parameter \"$_\" not defined!\n");
  }

# Some parameters must be writeable directories
  foreach my $key ( @{$h{WRITEABLE_DIRS}} )
  {
    $_ = $self->{$key};
    while ( my $x = readlink($_) ) { $_ = $x; } # Follow symlinks!

#   If the directory doesn't exist, attempt to create it...
    eval { mkpath $_ } unless -e;
    $self->Fatal("PERL_FATAL: $key directory $_ does not exist")   unless -e;
    $self->Fatal("PERL_FATAL: $key exists but is not a directory") unless -d;
    $self->Fatal("PERL_FATAL: $key directory $_ is not writeable") unless -w;
  }

# Some parameters must be writeable files if they exist, or the parent
# directory must be writeable. Non-definition is tacitly allowed
  foreach my $key ( @{$h{WRITEABLE_FILES}} )
  {
    if ( defined($_=$self->{$key}) )
    {
      while ( my $x = readlink($_) ) { $_ = $x; } # Follow symlinks!
      if ( -e $_ )
      {
#       If it exists, it better be a writeable file
        $self->Fatal("PERL_FATAL: $key exists but is not a file") unless -f;
        $self->Fatal("PERL_FATAL: $key file $_ is not writeable") unless -w;
      }
      else
      {
#       If it doesn't exist, the parent must be a writeable directory
#       If that parent directory doesn't exist, attempt to create it...
        if ( ! -e )
        {
          $_ = dirname($_);
          eval { mkpath $_ } unless -e;
        }
        $self->Fatal("PERL_FATAL: $key directory $_ does not exist")   unless -e;
        $self->Fatal("PERL_FATAL: $key exists but is not a directory") unless -d;
        $self->Fatal("PERL_FATAL: $key directory $_ is not writeable") unless -w;
      }
    }
  }

  if ( !defined($self->{LOGFILE}) && !$self->{NODAEMON} )
  {
#   LOGFILE not defined is fatal unless NODAEMON is set!
    $self->Fatal("PERL_FATAL: LOGFILE not set but process will run as a daemon");
  }

  return $errors;
}

# Dummy functions for Dropbox module
sub readInbox {}
sub readPending {}
sub readOutbox {}
sub renameDrop {}
sub inspectDrop {}
sub markBad {}
sub processInbox {}
sub processOutbox {}
sub processWork {}
sub processIdle {}
sub cleanDropbox { }

# Dummy functions for DB module
sub connectAgent {}
sub disconnectAgent {}
sub rollbackOnError {}
sub checkNodes {}
sub identifyAgent {}
sub updateAgentStatus {}
sub checkAgentMessages {}
sub expandNodes {}
sub myNodeFilter {}
sub otherNodeFilter {}

# Dummy functions for Cycle module
sub preprocess {}
sub _start {}
sub _preprocess {}
sub _process_start {}
sub _process_stop {}
sub _maybeStop {}
sub _stop {}
sub _make_stats { my $self = shift; $self->make_stats(); }
sub _child {}
sub _default { }

# Check if the agent should stop.  If the stop flag is set, cleans up
# and quits.  Otherwise returns.
sub maybeStop
{
    my $self = shift;

    # Check for the stop flag file.  If it exists, quit: remove the
    # pidfile and the stop flag and exit.
    return if ! -f $self->{STOPFILE};
    $self->Note("exiting from stop flag");
    $self->Notify("exiting from stop flag");
    $self->doStop();
}

sub doExit{ my ($self,$rc) = @_; exit($rc); }

=head1 Running agents as daemons

Agents will, be default, become daemons by forking, disconnecting from the
terminal, and starting their own process group. If you're trying to debug
them this can be a bit of a problem, so you can turn off this behaviour by
passing the NODAEMON flag with a non-zero value to the agents constructor.

=cut

# Turn the process into a daemon.  This causes the process to lose
# any controlling terminal by forking into background.
sub daemon
{
    my ($self, $me) = @_;
    my $pid;

    # Open the pid file.
    open(PIDFILE, "> $self->{PIDFILE}")
	|| die "$me: fatal error: cannot write to PID file ($self->{PIDFILE}): $!\n";
    $me = $self->{ME} unless $me;
    if ( $self->{NODAEMON} )
    {
#     I may not be a daemon, but I still have to write the PIDFILE, or the
#     watchdog may start another incarnation of me!
      ((print PIDFILE "$$\n") && close(PIDFILE))
	or die "$me: fatal error: cannot write to PID file ($self->{PIDFILE}): $!\n";
      close PIDFILE;
      return;
    }

    # Fork once to go to background
    die "failed to fork into background: $!\n"
	if ! defined ($pid = fork());
    close STDERR if $pid; # Hack to suppress misleading POE kernel warning
    exit(0) if $pid;

    # Make a new session
    die "failed to set session id: $!\n"
	if ! defined setsid();

    # Fork another time to avoid reacquiring a controlling terminal
    die "failed to fork into background: $!\n"
	if ! defined ($pid = fork());
    close STDERR if $pid; # Hack to suppress misleading POE kernel warning
    exit(0) if $pid;

    # Clear umask
    # umask(0);

    # Write our pid to the pid file while we still have the output.
    ((print PIDFILE "$$\n") && close(PIDFILE))
	or die "$me: fatal error: cannot write to $self->{PIDFILE}: $!\n";

    # Indicate we've started
    print "$me: pid $$", ( $self->{DROPDIR} ? " started in $self->{DROPDIR}" : '' ), "\n";

    # Close/redirect file descriptors
    $self->{LOGFILE} = "/dev/null" if ! defined $self->{LOGFILE};
    open (STDOUT, ">> $self->{LOGFILE}")
	or die "$me: cannot redirect output to $self->{LOGFILE}: $!\n";
    open (STDERR, ">&STDOUT")
	or die "Can't dup STDOUT: $!";
    open (STDIN, "</dev/null");
    $|=1; # Flush output line-by-line
}

=head1 User hooks

There are a number of user-hooks for overriding base-class behaviour at
various points. If you choose to you them you should check what the base-class
method does, and insert a call to C<< $self->SUPER::method >> somewhere
appropriate, if needed.

=head2 init

Called from C<< process, >> this method makes sure that all parameters that are
supposed to be hashes or arrays are correctly initialised. See the description
of initialising agents, above, for details.

You should not normally need to override the default init method, but if you
do you should call this base method early in the overridden code, via
C<< $self->SUPER::init >>.

Unlike C<< isInvalid >>, C<< init >> does have side-effects, so should not be
called at random in your code. The advantage of having an C<< init >> method,
instead of doing everything in the constructor, is that you can defer some
checks until you intend to use the object. This will be useful when/if we get
round to running more than one agent in the same process, for example.

=cut

sub init
{
  my $self = shift;
  my %h = @_;
  @{$h{ARRAYS}} = @array_params unless $h{ARRAYS};
  @{$h{HASHES}} = @hash_params  unless $h{HASHES};
  foreach ( @{$h{ARRAYS}} )
  {
    if ( !defined($self->{$_}) )
    {
      $self->{$_} = [];
      next;
    }
    next if ref($self->{$_}) eq 'ARRAY';
    my @x = split(',',$self->{$_});
    $self->{$_} = \@x;
  }

  foreach ( @{$h{HASHES}} )
  {
    if ( !defined($self->{$_}) )
    {
      $self->{$_} = {};
      next;
    }
#   Is this the right thing to do here...?
    next if ref($self->{$_}) eq 'HASH';
    my %x = split(',',$self->{$_});
    $self->{$_} = \%x;
  }
}

# Actually make the agent stop and exit.
sub doStop
{
    my ($self) = @_;

    # Run agent cleanup
    eval { $self->stop(); };
    $self->rollbackOnError();

    # Force database off
    eval { $self->{DBH}->rollback() } if $self->{DBH};
    eval { &disconnectFromDatabase($self, $self->{DBH}, 1) } if $self->{DBH};

    # Remove stop flag and pidfile
    unlink($self->{PIDFILE});
    #unlink($self->{STOPFILE});

    POE::Kernel->alarm_remove_all();
    $self->doExit(0);
}


=head2 stop

Agent subclasses implement this in order to do any final clean up
actions before exiting.  The actions should finish promptly.

=cut

sub stop {}

=head2 processDrop

Override this in an agent subclass to process a drop file

=cut

sub processDrop {}

# Manage work queue.  If there are previously pending work, finish
# it, otherwise look for and process new inbox drops.

sub process
{
  my $self = shift;
  # Work.

  my $pmon = $self->{pmon};
  $self->processInbox();
  my @pending = $self->processWork();
  $self->processOutbox();
  $self->processIdle(@pending);
  $self->Dbgmsg($pmon->FormatStates) if $self->{DEBUG};
  # Check to see if the config-file should be reloaded
  $self->checkConfigFile();
}

sub checkConfigFile
{
  my $self = shift;
  my ($config,$mtime,$Config);
  return unless $self->can('reloadConfig');

  $config = $self->{CONFIG_FILE};
  $mtime = (stat($config))[9];
  if ( $mtime > $self->{CONFIGURATION}{_readTime} )
  {
    $self->Logmsg("Config file has changed, re-reading...");
    $Config = PHEDEX::Core::Config->new();
    $Config->readConfig( $self->{CONFIG_FILE} );
    $self->{CONFIGURATION} = $Config;
    $self->reloadConfig($Config);
  }
}

# Agents should override this to do their work. It's an unfortunate name
# now, the work is done in the 'idle' routine :-(
sub idle { }

=head2 reloadConfig

Declare this in an agent subclass to reload the configuration after the
config-file has changed. Do not declare it if you don't want the config
file monitored.

=cut

#sub reloadConfig {}

sub AgentType
{
  my ($self,$agent_type) = @_;

  if ( !defined($agent_type) )
  {
    $agent_type = (caller(1))[0];
    $agent_type =~ s%^PHEDEX::%%;
    $agent_type =~ s%::Agent%%;
    $agent_type =~ s%::%%g;
  }
  return $self->{ME} = $agent_type;
}

# Print statistics
sub make_stats
{
  my $self = shift;
  my ($delay,$totalWall,$totalOnCPU,$totalOffCPU,$summary);
  my ($pmon,$h,$onCPU,$offCPU,$count);

  $totalWall = $totalOnCPU = $totalOffCPU = 0;
  $pmon = $self->{pmon};
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
      my $waittime = $self->{WAITTIME} || 0;
      if ( !defined($median) ) { print "median not defined\n"; }
      if ( !defined($max   ) ) { print "max    not defined\n"; }
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

    $self->{stats}{process} = undef;
  }

  if ( $summary )
  {

    $summary = 'AGENT_STATISTICS' . $summary;
    $self->Logmsg($summary) if $self->{STATISTICS_DETAIL};
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
  { $summary .= " Sizeof($self->{ME})=$size"; }
  if ( $size = PHEDEX::Monitoring::Process::TotalSizes() )
  { $summary .= " $size"; }
  $summary .= "\n";

  $self->Logmsg($summary);
  $self->Notify($summary);
  return $summary;
}

sub StartedDoingSomething
{
  my ($self,$num) = @_;
  $num = 1 unless defined $num;
  $self->{_DOINGSOMETHING} += $num;
  return $self->{_DOINGSOMETHING};
}

sub FinishedDoingSomething
{
  my ($self,$num) = @_; 
  $num = 1 unless defined $num;
  $self->{_DOINGSOMETHING} -= $num;
  if ( $self->{_DOINGSOMETHING} < 0 )
  {
    $self->Logmsg("FinishedDoingSomething too many times: ",$self->{_DOINGSOMETHING}) if $self->{DEBUG};
    $self->{_DOINGSOMETHING} = 0;
  }
  return $self->{_DOINGSOMETHING};
}

1;
