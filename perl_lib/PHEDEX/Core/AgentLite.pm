package PHEDEX::Core::AgentLite;

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
use POE;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;
use PHEDEX::Core::Config;                                                       
use PHEDEX::Monitoring::Process;
use PHEDEX::Core::Loader;

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
arrays or 
hashes and either set them to null arrays/hashes if they are not defined 
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
	  OUTDIR	=> undef,
	  STOPFLAG	=> undef,
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
	  NOTIFICATION_HOST	=> undef,
	  NOTIFICATION_PORT	=> undef,
	  _DOINGSOMETHING	=> 0,
	  _DONTSTOPME		=> 0,
	  STATISTICS_INTERVAL	=> 3600,	# reporting frequency
	  STATISTICS_DETAIL	=>    1,	# reporting level: 0, 1, or 2
	);

our @array_params = qw / STARTTIME NODES IGNORE_NODES ACCEPT_NODES /;
our @hash_params  = qw / BAD JUNK /;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = $class->SUPER::new(@_);
    my %p = %params;

    my %args = (@_);
    my $me = $self->AgentType($args{ME});

    my @agent_reject = ( qw / Template / );
    my $agent_loader = PHEDEX::Core::Loader->new( NAMESPACE => 'PHEDEX::Core::Agent',
                                                  REJECT    => \@agent_reject );
#   Retrieve the agent environment, if I can.
    my ($config,$cfg,$label,$key,$val);
    $config = $args{CONFIG_FILE} || $p{CONFIG_FILE};
    $label  = $args{LABEL}       || $p{LABEL};
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

#   Before basic validation, we need to derive a few other parameters.
    $self->{DROPDIR} .= '/' unless $self->{DROPDIR} =~ m%\/$%;
    $self->{INBOX}    = $self->{DROPDIR} . 'inbox'; # unless $self->{INBOX};
    $self->{OUTDIR}   = $self->{DROPDIR} . 'outbox';# unless $self->{OUTDIR};
    $self->{PIDFILE}  = $self->{DROPDIR} . 'pid';   # unless $self->{PIDFILE};
    $self->{STOPFLAG} = $self->{DROPDIR} . 'stop';  # unless $self->{STOPFLAG};
    $self->{WORKDIR}  = $self->{DROPDIR} . 'work';  # unless $self->{WORKDIR};
#   Basic validation: Explicitly call the base method to validate only the
#   core agent. This will be called again in the 'process' method, on the
#   derived agent. No harm in that!

#   Load the Dropbox modules
    $self->{_Dropbox} = $agent_loader->Load('Dropbox')->new( _AC => $self );

    die "$me: Failed validation, exiting\n" 
	if PHEDEX::Core::Agent::Dropbox::isInvalid($self);

    foreach my $dir (@{$self->{NEXTDIR}}) {
	if ($dir =~ /^([a-z]+):/) {
            die "$me: fatal error: unrecognised bridge $1" if ($1 ne "scp" && $1 ne "rfio");
	} else {
            die "$me: fatal error: no downstream drop box\n" if ! -d $dir;
	}
    }

    if (-f $self->{PIDFILE})
    {
	if (my $oldpid = &input($self->{PIDFILE}))
	{
	    chomp ($oldpid);
	    die "$me: pid $oldpid already running in $self->{DROPDIR}\n"
		if kill(0, $oldpid);
	    print "$me: pid $oldpid dead in $self->{DROPDIR}, overwriting\n";
	    unlink ($self->{PIDFILE});
	}
    }

    if (-f $self->{STOPFLAG})
    {
	print "$me: removing old stop flag $self->{STOPFLAG}\n";
	unlink ($self->{STOPFLAG});
    }

    bless $self, $class;
    # If required, daemonise, write pid file and redirect output.
    $self->daemon();

#   Start a POE session for myself
    POE::Session->create
      (
        object_states =>
        [
          $self =>
          {
            _preprocess		=> '_preprocess',
            _process_start	=> '_process_start',
            _process_stop	=> '_process_stop',
            _maybeStop		=> '_maybeStop',
	    _make_stats		=> '_make_stats',

            _start   => '_start',
            _stop    => '_stop',
	    _child   => '_child',
            _default => '_default',
          },
        ],
      );


#   Finally, start some self-monitoring...
    $self->{pmon} = PHEDEX::Monitoring::Process->new();

    # Initialise subclass.
    $self->init();

#   Load the DB modules
    $self->{_DB} = $agent_loader->Load('DB')->new( _AC => $self );

    # Validate the object!
    die "Agent ",$self->{ME}," failed validation\n" if $self->isInvalid();

#   Announce myself...
    $self->Notify("label=$label");
    return $self;
}

# Catch methods derivated from plugins: Dropbox, Cycle and  DB

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  return unless $attr =~ /[^A-Z]/;        # skip all-cap methods

  if ( $self->{_Dropbox}->can($attr) ) { $self->{_Dropbox}->$attr(@_);
  } elsif ( $self->{_DB}->can($attr) ) { $self->{_DB}->$attr(@_);
  } else { $self->Alert("Un-known method for PHEDEX::Core::Agent"); }
}



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
	|| die "$me: fatal error: cannot write to $self->{PIDFILE}: $!\n";
    $me = $self->{ME} unless $me;
    if ( $self->{NODAEMON} )
    {
#     I may not be a daemon, but I still have to write the PIDFILE, or the
#     watchdog may start another incarnation of me!
      ((print PIDFILE "$$\n") && close(PIDFILE))
	or die "$me: fatal error: cannot write to $self->{PIDFILE}: $!\n";
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
    print "$me: pid $$ started in $self->{DROPDIR}\n";

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


# Check if the agent should stop.  If the stop flag is set, cleans up
# and quits.  Otherwise returns.
sub maybeStop
{
    my $self = shift;

    # Check for the stop flag file.  If it exists, quit: remove the
    # pidfile and the stop flag and exit.
    return if ! -f $self->{STOPFLAG};
    $self->Note("exiting from stop flag");
    $self->Notify("exiting from stop flag");
    $self->doStop();
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
#    unlink($self->{STOPFLAG});

    POE::Kernel->alarm_remove_all();
    $self->doExit(0);
}

sub doExit{ my ($self,$rc) = @_; exit($rc); }

=head2 stop

Agent subclasses implement this in order to do any final clean up
actions before exiting.  The actions should finish promptly.

=cut

sub stop {}

=head2 processDrop

Override this in an agent subclass to process a drop file

=cut

sub processDrop
{}

# Introduced for POE-based agents to allow process to become a true loop
sub preprocess
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];

# # Initialise subclass.
# $self->init();
# # Validate the object!
# die "Agent ",$self->{ME}," failed validation\n" if $self->isInvalid();
# $self->initWorkers();

  # Restore signals.  Oracle apparently is in habit of blocking them.
  $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub { $self->doStop() };
}

# Manage work queue.  If there are previously pending work, finish
# it, otherwise look for and process new inbox drops.
sub process
{
  my $self = shift;
  # Work.
  my $drop;
  my $pmon = $self->{pmon};

  # Check for new inputs.  Move inputs to pending work queue.
  $self->maybeStop();
  $pmon->State('inbox','start');
  foreach $drop ($self->readInbox ())
  {
    $self->maybeStop();
    if (! &mv ("$self->{INBOX}/$drop", "$self->{WORKDIR}/$drop"))
    {
#     Warn and ignore it, it will be returned again next time around
      $self->Alert("failed to move job '$drop' to pending queue: $!");
    }
  }
  $pmon->State('inbox','stop');

  # Check for pending work to do.
  $self->maybeStop();
  $pmon->State('work','start');
  my @pending = $self->readPending ();
  my $npending = scalar (@pending);
  foreach $drop (@pending)
  {
    $self->maybeStop();
    $self->processDrop ($drop, --$npending);
  }
  $pmon->State('work','stop');

  # Check for drops waiting for transfer to the next agent.
  $self->maybeStop();
  $pmon->State('outbox','start');
  foreach $drop ($self->readOutbox())
  {
    $self->maybeStop();
    $self->relayDrop ($drop);
  }
  $pmon->State('outbox','stop');

  # Wait a little while.
  $self->maybeStop();
  $pmon->State('idle','start');
  $self->idle (@pending);
  $pmon->State('idle','stop');
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
    $Config = PHEDEX::Core::Config->new( PARANOID => 1 );
    $Config->readConfig( $self->{CONFIG_FILE} );
    $self->{CONFIGURATION} = $Config;
    $self->reloadConfig($Config);
  }
}

# Agents should override this to do their work. It's an unfortunate name
# now, the work is done in the 'idle' routine :-(
sub idle { }

# Sleep for a time, checking stop flag every once in a while.
sub nap
{
    my ($self, $time) = @_;
    my $target = &mytimeofday () + $time;
    do { $self->maybeStop(); sleep (1); } while (&mytimeofday() < $target);
}

=head2 reloadConfig

Declare this in an agent subclass to reload the configuration after the
config-file has changed. Do not declare it if you don't want the config
file monitored.

=cut

#sub reloadConfig {}

sub _start
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  $self->Logmsg("starting Agent session (id=",$session->ID,")");
  $self->{SESSION_ID} = $session->ID;
# $kernel->post($self->{SESSION_ID},'_preprocess') if $self->can('preprocess');
  $kernel->yield('_preprocess'); # if $self->can('preprocess');
  if ( $self->can('_poe_init') )
  {
    $kernel->state('_poe_init',$self);
    $kernel->yield('_poe_init');
  }
  $kernel->yield('_process_start');
  $kernel->yield('_maybeStop');

  $self->Logmsg('STATISTICS: Reporting every ',$self->{STATISTICS_INTERVAL},' seconds, detail=',$self->{STATISTICS_DETAIL});
  $self->{stats}{START} = time;
# $self->{stats}{maybeStop} = 0;
# $self->{stats}{process} = {};
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
# $self->Dbgmsg("starting '_process_start'") if $self->{DEBUG};

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

# $self->Dbgmsg("ending '_process_start'") if $self->{DEBUG};
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

# $self->Dbgmsg("starting '_process_stop'") if $self->{DEBUG};
  if ( exists($self->{stats}{process}) )
  {
    $t = time;
    push @{$self->{stats}{process}{onCPU}}, $t - $self->{_start};
    $self->{stats}{process}{_offCPU} = $t;
  }

  $self->{_DONTSTOPME} = 0;
# $self->Dbgmsg("ending '_process_stop'") if $self->{DEBUG};
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
  print $self->Hdr, "ending, for lack of work...\n";
}

sub _make_stats
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
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
    $self->Notify($summary);# ,"\n") if $delay > 1.25;
  }

  my $now = time;
  $totalWall = $now - $self->{stats}{START};
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
