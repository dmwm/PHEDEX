package PHEDEX::Core::Agent;

=head1 NAME

PHEDEX::Core::Agent - POE-based Agent daemon base class

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::JobManager', 'PHEDEX::Core::Logging';
use POSIX;
use File::Path;
use File::Basename;
use Time::HiRes qw / time /;
use POE;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::RFIO;
use PHEDEX::Core::DB;
use PHEDEX::Core::Config;                                                       

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
	);

our @array_params = qw / STARTTIME NODES IGNORE_NODES ACCEPT_NODES /;
our @hash_params  = qw / BAD JUNK /;
our @required_params = qw / DROPDIR DBCONFIG /;
our @writeable_dirs  = qw / DROPDIR INBOX WORKDIR OUTDIR /;
our @writeable_files = qw / LOGFILE PIDFILE /;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = $class->SUPER::new(@_);
    my %p = %params;

    my %args = (@_);
    my $me = $self->AgentType($args{ME});

#   Retrieve the agent environment, if I can.
    my ($config,$cfg,$label,$key,$val);
    $config = $args{CONFIG_FILE} || $p{CONFIG_FILE};
    $label  = $args{LABEL}       || $p{LABEL};
    if ( $config && $label )
    {
      $cfg = PHEDEX::Core::Config->new();
      foreach ( split(',',$config) ) { $cfg->readConfig($_); }
      $self->{AGENT} = $cfg->select_agents($label);

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
    die "$me: Failed validation, exiting\n"
	if PHEDEX::Core::Agent::isInvalid( $self );

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
            _process	=> '_process',
            _maybeStop	=> '_maybeStop',

            _start   => '_start',
            _stop    => '_stop',
            _default => '_default',
          },
        ],
      );

    return $self;
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

    return if $self->{NODAEMON};
    $me = $self->{ME} unless $me;
    # Open the pid file.
    open(PIDFILE, "> $self->{PIDFILE}")
	|| die "$me: fatal error: cannot write to $self->{PIDFILE}: $!\n";

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

=head2 isInvalid

Called from the constructor, for the base class, and again from C<< process >>
for the derived class. This allows the basic PHEDEX::Core::Agent to be
validated before the derived class is fully initialised, and for the derived
class to be fully validated before it is used.

You do not need to provide an override for the derived class if you don't
want to, nothing bad will happen.

If you do need to validate your derived class you can do anything you want in
this method. Note that the intention is that this method does not change the
object, and can in principle be called from anywhere. Beyond that, any sort
of checks you want are reasonable.

=cut

sub isInvalid
{
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

sub initWorkers
{
    my $self = shift;
    return if ! $self->{NWORKERS};
    $self->{WORKERS} = [ (0) x $self->{NWORKERS} ];
    $self->checkWorkers();
}

# Ensure workers are running, if not, restart them
sub checkWorkers
{
    my $self = shift;
    my $nworkers = scalar @{$self->{WORKERS}};
    for (my $i = 0; $i < $nworkers; ++$i)
    {
	if (! $self->{WORKERS}[$i] || waitpid($self->{WORKERS}[$i], WNOHANG) > 0) {
	    my ($old, $new) = ($self->{WORKERS}[$i], $self->startWorker ($i));
	    $self->{WORKERS}[$i] = $new;

	    if (! $old) {
		$self->Logmsg ("worker $i ($new) started");
	    } else {
	        $self->Logmsg ("worker $i ($old) stopped, restarted as $new");
	    }
	}
    }
}

# Start a worker
sub startWorker
{
    my $self = shift;
    die "derived class asked for workers, but didn't override startWorker!\n";
}

# Stop workers
sub stopWorkers
{
    my $self = shift;
    return if ! $self->{NWORKERS};

    # Make workers quit
    my @workers = @{$self->{WORKERS}};
    my @stopflags = map { "$self->{DROPDIR}/worker-$_/stop" }
    			0 .. ($self->{NWORKERS}-1);
    $self->Note ("stopping worker threads");
    &touch (@stopflags);
    while (scalar @workers)
    {
	my $pid = waitpid (-1, 0);
	@workers = grep ($pid ne $_, @workers);
	$self->Logmsg ("child process $pid exited, @{[scalar @workers]} workers remain") if $pid > 0;
    }
    unlink (@stopflags);
}

# Pick least-loaded worker
sub pickWorker
{
    my ($self) = @_;
    my $nworkers = scalar @{$self->{WORKERS}};
    my $basedir = $self->{DROPDIR};
    return (sort { $a->[1] <=> $b->[1] }
    	    map { [ $_, scalar @{[<$basedir/worker-$_/{inbox,work}/*>]} ] }
	    0 .. $nworkers-1) [0]->[0];
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
    $self->doStop();
}

# Actually make the agent stop and exit.
sub doStop
{
    my ($self) = @_;

    # Force database off
    eval { $self->{DBH}->rollback() } if $self->{DBH};
    eval { &disconnectFromDatabase($self, $self->{DBH}, 1) } if $self->{DBH};

    # Remove stop flag and pidfile
    unlink($self->{PIDFILE});
    unlink($self->{STOPFLAG});

    # Stop the rest
    $self->killAllJobs() if @{$self->{JOBS}};
    $self->stopWorkers() if $self->{NWORKERS};
    $self->stop();
    exit (0);
}

=head2 stop

I have no idea what you would want to do with this...

=cut

sub stop {}

# Look for pending drops in inbox.
sub readInbox
{
    my $self = shift;

    die "$self->{ME}: fatal error: no inbox directory given\n" if ! $self->{INBOX};

    # Scan the inbox.  If this fails, file an alert but keep going,
    # the problem might be transient (just sleep for a while).
    my @files = ();
    $self->Alert("cannot list inbox(".$self->{INBOX}."): $!")
	if (! &getdir($self->{INBOX}, \@files));

    # Check for junk
    foreach my $f (@files)
    {
	# Make sure we like it.
	if (! -d "$self->{INBOX}/$f")
	{
	    $self->Alert("junk ignored in inbox: $f") if ! exists $self->{JUNK}{$f};
	    $self->{JUNK}{$f} = 1;
        }
	else
	{
	    delete $self->{JUNK}{$f};
        }
    }

    # Return those that are ready
    return grep(-f "$self->{INBOX}/$_/go", @files);
}

# Look for pending tasks in the work directory.
sub readPending
{
    my $self = shift;
    die "$self->{ME}: fatal error: no work directory given\n" if ! $self->{WORKDIR};

    # Scan the work directory.  If this fails, file an alert but keep
    # going, the problem might be transient.
    my @files = ();
    $self->Alert("cannot list workdir(".$self->{WORKDIR}."): $!")
	if (! getdir($self->{WORKDIR}, \@files));

    return @files;
}

# Look for tasks waiting for transfer to next agent.
sub readOutbox
{
    my $self = shift;
    die "$self->{ME}: fatal error: no outbox directory given\n" if ! $self->{OUTDIR};

    # Scan the outbox directory.  If this fails, file an alert but keep
    # going, the problem might be transient.
    my @files = ();
    $self->Alert("cannot list outdir(".$self->{OUTDIR}."): $!")
	if (! getdir ($self->{OUTDIR}, \@files));

    return @files;
}

# Rename a drop to a new name
sub renameDrop
{
    my ($self, $drop, $newname) = @_;
    &mv ("$self->{WORKDIR}/$drop", "$self->{WORKDIR}/$newname")
        || do { $self->Alert ("can't rename $drop to $newname"); return 0; };
    return 1;
}

# Utility to undo from failed scp bridge operation
sub scpBridgeFailed
{
    my ($self,$msg, $remote) = @_;
    # &runcmd ("ssh", $host, "rm -fr $remote");
    $self->Alert ($msg);
    return 0;
}

sub scpBridgeDrop
{
    my ($self,$source, $target) = @_;

    return $self->scpBridgeFailed ("failed to chmod $source", $target)
        if ! chmod(0775, "$source");

    return $self->scpBridgeFailed ("failed to copy $source", $target)
        if &runcmd ("scp", "-rp", "$source", "$target");

    return $self->scpBridgeFailed ("failed to copy /dev/null to $target/go", $target)
        if &runcmd ("scp", "/dev/null", "$target/go"); # FIXME: go-pending?

    return 1;
}

# Utility to undo from failed rfio bridge operation
sub rfioBridgeFailed
{
    my ($self,$msg, $remote) = @_;
    &rfrmall ($remote) if $remote;
    $self->Alert ($msg);
    return 0;
}

sub rfioBridgeDrop
{
    my ($self,$source, $target) = @_;
    my @files = <$source/*>;
    do { $self->Alert ("empty $source"); return 0; } if ! scalar @files;

    return $self->rfioBridgeFailed ("failed to create $target")
        if ! &rfmkpath ($target);

    foreach my $file (@files)
    {
        return $self->rfioBridgeFailed ("failed to copy $file to $target", $target)
            if ! &rfcp ("$source/$file", "$target/$file");
    }

    return $self->rfioBridgeFailed ("failed to copy /dev/null to $target", $target)
        if ! &rfcp ("/dev/null", "$target/go");  # FIXME: go-pending?

    return 1;
}

# Transfer the drop to the next agent
sub relayDrop
{
    my ($self, $drop) = @_;

    # Move to output queue if not done yet
    if (-d "$self->{WORKDIR}/$drop")
    {
        &mv ("$self->{WORKDIR}/$drop", "$self->{OUTDIR}/$drop") || return;
    }

    # Check if we've already successfully copied this one downstream.
    # If so, just nuke it; manual recovery is required to kick the
    # downstream ones forward.
    if (-f "$self->{OUTDIR}/$drop/gone") {
	&rmtree ("$self->{OUTDIR}/$drop");
	return;
    }

    # Clean up our markers
    &rmtree("$self->{OUTDIR}/$drop/go");
    &rmtree("$self->{OUTDIR}/$drop/gone");
    &rmtree("$self->{OUTDIR}/$drop/bad");
    &rmtree("$self->{OUTDIR}/$drop/done");

    # Copy to the next ones.  We want to be careful with the ordering
    # here -- we want to copy the directory exactly once, ever.  So
    # execute in an order that is safe even if we get interrupted.
    if (scalar @{$self->{NEXTDIR}} == 0)
    {
	&rmtree ("$self->{OUTDIR}/$drop");
    }
    elsif (scalar @{$self->{NEXTDIR}} == 1 && $self->{NEXTDIR}[0] !~ /^([a-z]+):/)
    {
	-d "$self->{NEXTDIR}[0]/inbox"
	    || mkdir "$self->{NEXTDIR}[0]/inbox"
	    || -d "$self->{NEXTDIR}[0]/inbox"
	    || return $self->Alert("cannot create $self->{NEXTDIR}[0]/inbox: $!");

	# Make sure the destination doesn't exist yet.  If it does but
	# looks like a failed copy, nuke it; otherwise complain and give up.
	if (-d "$self->{NEXTDIR}[0]/inbox/$drop"
	    && -f "$self->{NEXTDIR}[0]/inbox/$drop/go-pending"
	    && ! -f "$self->{NEXTDIR}[0]/inbox/$drop/go") {
	    &rmtree ("$self->{NEXTDIR}[0]/inbox/$drop")
        } elsif (-d "$self->{NEXTDIR}[0]/inbox/$drop") {
	    return $self->Alert("$self->{NEXTDIR}[0]/inbox/$drop already exists!");
	}

	&mv ("$self->{OUTDIR}/$drop", "$self->{NEXTDIR}[0]/inbox/$drop")
	    || return $self->Alert("failed to copy $drop to $self->{NEXTDIR}[0]/$drop: $!");
	&touch ("$self->{NEXTDIR}[0]/inbox/$drop/go")
	    || $self->Alert ("failed to make $self->{NEXTDIR}[0]/inbox/$drop go");
    }
    else
    {
        foreach my $dir (@{$self->{NEXTDIR}})
        {
	    if ($dir =~ /^scp:/) {
		$self->scpBridgeDrop ("$self->{OUTDIR}/$drop", "$dir/inbox/$drop");
		next;
	    } elsif ($dir =~ /^rfio:/) {
		$self->rfioBridgeDrop ("$self->{OUTDIR}/$drop", "$dir/inbox/$drop");
		next;
	    }

	    # Local.  Create destination inbox if necessary.
	    -d "$dir/inbox"
	        || mkdir "$dir/inbox"
	        || -d "$dir/inbox"
	        || return $self->Alert("cannot create $dir/inbox: $!");

	    # Make sure the destination doesn't exist yet.  If it does but
	    # looks like a failed copy, nuke it; otherwise complain and give up.
	    if (-d "$dir/inbox/$drop"
	        && -f "$dir/inbox/$drop/go-pending"
	        && ! -f "$dir/inbox/$drop/go") {
	        &rmtree ("$dir/inbox/$drop")
            } elsif (-d "$dir/inbox/$drop") {
	        return $self->Alert("$dir/inbox/$drop already exists!");
	    }

	    # Copy to the next stage, preserving everything
	    my $status = &runcmd  ("cp", "-Rp", "$self->{OUTDIR}/$drop", "$dir/inbox/$drop");
	    return $self->Alert ("can't copy $drop to $dir/inbox: $status") if $status;

	    # Mark it almost ready to go
	    &touch("$dir/inbox/$drop/go-pending");
        }

        # Now mark myself gone downstream so we won't try copying again
        # (FIXME: error checking?)
        &touch ("$self->{OUTDIR}/$drop/gone");

        # All downstream versions copied safely now.  Now really let them
        # go onwards.  If this fails, it's not fatal because someone can
        # still manually fix them to be in ready state.  We haven't lost
        # anything.  (FIXME: avoidable?)
        foreach my $dir (@{$self->{NEXTDIR}}) {
	    next if $dir =~ /^([a-z]+):/; # FIXME: also handle here?
	    &mv("$dir/inbox/$drop/go-pending", "$dir/inbox/$drop/go");
        }

        # Now junk it here
        &rmtree("$self->{OUTDIR}/$drop");
    }
}

# Check what state the drop is in and indicate if it should be
# processed by agent-specific code.
sub inspectDrop
{
    my ($self, $drop) = @_;

    if (! -d "$self->{WORKDIR}/$drop")
    {
	$self->Alert("$drop is not a pending task");
	return 0;
    }

    if (-f "$self->{WORKDIR}/$drop/bad")
    {
	$self->Alert("$drop marked bad, skipping") if ! exists $self->{BAD}{$drop};
	$self->{BAD}{$drop} = 1;
	return 0;
    }

    if (! -f "$self->{WORKDIR}/$drop/go")
    {
	$self->Alert("$drop is incomplete!");
	return 0;
    }

    if (-f "$self->{WORKDIR}/$drop/done")
    {
	&relayDrop ($self, $drop);
	return 0;
    }

    return 1;
}

# Mark a drop bad.
sub markBad
{
    my ($self, $drop) = @_;
    &touch("$self->{WORKDIR}/$drop/bad");
    $self->Logmsg("stats: $drop @{[&formatElapsedTime($self->{STARTTIME})]} failed");
}

=head2 processDrop

I have no idea what you would want to do with this either...

=cut

sub processDrop
{}

# Introduced for POE-based agents to allow process to become a true loop
sub preprocess
{
  my $self = shift;

  # Initialise subclass.
  $self->init();
  # Validate the object!
  die "Agent ",$self->{ME}," failed validation\n" if $self->isInvalid();
  $self->initWorkers();

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

  # Check for new inputs.  Move inputs to pending work queue.
  $self->maybeStop();
  foreach $drop ($self->readInbox ())
  {
    $self->maybeStop();
    if (! &mv ("$self->{INBOX}/$drop", "$self->{WORKDIR}/$drop"))
    {
#     Warn and ignore it, it will be returned again next time around
      $self->Alert("failed to move job '$drop' to pending queue: $!");
    }
  }

  # Check for pending work to do.
  $self->maybeStop();
  my @pending = $self->readPending ();
  my $npending = scalar (@pending);
  foreach $drop (@pending)
  {
    $self->maybeStop();
    $self->processDrop ($drop, --$npending);
  }

  # Check for drops waiting for transfer to the next agent.
  $self->maybeStop();
  foreach $drop ($self->readOutbox())
  {
    $self->maybeStop();
    $self->relayDrop ($drop);
  }

  # Wait a little while.
  $self->maybeStop();
# $self->Dbgmsg("starting idle()") if $self->{DEBUG};
  my $t1 = &mytimeofday();
  $self->idle (@pending);
  my $t2 = &mytimeofday();
  $self->Dbgmsg(sprintf("cycle time %.6f s", $t2-$t1)) if $self->{DEBUG};
#  if ($self->{AUTO_NAP}) {
#$self->Dbgmsg("sleeping for $self->{WAITTIME} s") if $self->{VERBOSE};
#$self->nap ($self->{WAITTIME});
#  }
}

# Wait between scans
sub idle
{
    my $self = shift;
#   $self->nap ($self->{WAITTIME});
}

# Sleep for a time, checking stop flag every once in a while.
sub nap
{
    my ($self, $time) = @_;
    my $target = &mytimeofday () + $time;
    do { $self->maybeStop(); sleep (1); } while (&mytimeofday() < $target);
}

# Connect to database and identify self
sub connectAgent
{
    my ($self, $identify) = @_;
    my $dbh;

#    if ( $self->{SHARED_DBH} )
#    {
#      $self->Logmsg("Looking for a DBH to share") if $self->{DEBUG};
#      if ( exists($Agent::Registry{DBH}) )
#      {
#        $self->{DBH} = $dbh = $Agent::Registry{DBH};
#        $self->Logmsg("using shared DBH=$dbh") if $self->{DEBUG};
#      }
#      else
#      {
#        $self->Logmsg("Creating new DBH") if $self->{DEBUG};
#        $Agent::Registry{DBH} = $dbh = &connectToDatabase($self) unless $dbh;
#        $self->Logmsg("Sharing DBH=$dbh") if $self->{DEBUG};
#      }
#    }
#    else
#    {
#$self->{DEBUG}++;
      $dbh = &connectToDatabase($self);
#$self->{DEBUG}--;
#     $self->Logmsg("Using private DBH=$dbh") if $self->{DEBUG};
#    }

    $self->checkNodes();

    # Make myself known if I have a name.  If this fails, the database
    # is probably so wedged that we can't do anything useful, so bail
    # out.  The caller is in charge of committing or rolling back on
    # any errors raised.
    if ($self->{MYNODE}) {
	$self->updateAgentStatus();
	$self->identifyAgent();
	$self->checkAgentMessages();
    }

    return $dbh;
}

# Disconnects an agent.  Well, not really.  See
# PHEDEX::Core::DB::disconnectFromDatabase.
sub disconnectAgent
{
    my ($self, $force) = @_;
    return if ($self->{SHARED_DBH});
    &disconnectFromDatabase($self, $self->{DBH}, $force);
}

# Check that nodes used are valid
sub checkNodes
{
    my ($self) = @_;

    my $q = &dbprep($self->{DBH}, qq{
        select count(*) from t_adm_node where name like :pat});

    &dbbindexec($q, ':pat' => $self->{MYNODE});
    $self->Fatal("'$self->{MYNODE}' does not match any node known to TMDB, check -node argument\n")
	if ($self->{MYNODE} && ! $q->fetchrow());

    my %params = (NODES => '-nodes', ACCEPT_NODES => '-accept', IGNORE_NODES => '-ignore');
    while (my ($param, $arg) = each %params) {
	foreach my $pat (@{$self->{$param}}) {
	    &dbbindexec($q, ':pat' => $pat);
	    $self->Fatal("'$pat' does not match any node known to TMDB, check $arg argument\n")
		unless $q->fetchrow();
	}
    }

    return 1;
}

# Identify the version of the code packages running in this agent.
# Scan all the perl modules imported into this process, and identify
# each significant piece of code.  We collect following information:
# relative file name, file size in bytes, MD5 sum of the file contents,
# PhEDEx distribution version, the CVS revision and tag of the file.
sub identifyAgent
{
  my ($self) = @_;
  my $dbh = $self->{DBH};
  my $now = &mytimeofday();

  # If we have a new database connection, log agent start-up and/or
  # new database connection into the logging table.
  if ($dbh->{private_phedex_newconn})
  {
    my ($ident) = qx(ps -p $$ wwwwuh 2>/dev/null);
    chomp($ident) if $ident;
    &dbexec($dbh, qq{
          insert into t_agent_log
          (time_update, reason, host_name, user_name, process_id,
           working_directory, state_directory, message)
          values
          (:now, :reason, :host_name, :user_name, :process_id,
           :working_dir, :state_dir, :message)},
          ":now" => $now,
          ":reason" => ($self->{DBH_AGENT_IDENTIFIED}{$self->{MYNODE}}
          ? "AGENT RECONNECTED" : "AGENT STARTED"),
          ":host_name" => $self->{DBH_ID_HOST},
          ":user_name" => scalar getpwuid($<),
          ":process_id" => $$,
          ":working_dir" => &getcwd(),
          ":state_dir" => $self->{DROPDIR},
          ":message" => $ident);
    $dbh->{private_phedex_newconn} = 0;
    $dbh->commit();
  }

  # Avoid re-identifying ourselves further if already done.
  return if $self->{DBH_AGENT_IDENTIFIED}{$self->{MYNODE}};

  # Get PhEDEx distribution version.
  my $distribution = undef;
  my $versionfile = $INC{'PHEDEX/Core/DB.pm'};
  $versionfile =~ s|/perl_lib/.*|/VERSION|;
  if (open (DBHVERSION, "< $versionfile"))
  {
    chomp ($distribution = <DBHVERSION>);
    close (DBHVERSION);
  }

  # Get all interesting modules loaded into this process.
  my @files = ($0, grep (m!(^|/)(PHEDEX|Toolkit|Utilities|Custom)/!, values %INC));
  return if ! @files;

  # Get the file data for each module: size, checksum, CVS info.
  my %fileinfo = ();
  my %cvsinfo = ();
  foreach my $file (@files)
  {
    my ($path, $fname) = ($file =~ m!(.*)/(.*)!);
    $fname = $file if ! defined $fname;
    next if exists $fileinfo{$fname};

    if (defined $path)
    {
      if (-d $path && ! exists $cvsinfo{$path} && open (DBHCVS, "< $path/CVS/Entries"))
      {
        while (<DBHCVS>)
        {
          chomp;
          my ($type, $cvsfile, $rev, $date, $flags, $sticky) = split("/", $_);
          next if ! $cvsfile || ! $rev;
          $cvsinfo{$path}{$cvsfile} = {
	      REVISION => $rev,
	      REVDATE => $date,
	      FLAGS => $flags,
	      STICKY => $sticky
          };
        }
        close (DBHCVS);
      }

      $fileinfo{$fname} = $cvsinfo{$path}{$fname}
        if exists $cvsinfo{$path}{$fname};
    }

    if (-f $file)
    {
      if (my $cksum = qx(md5sum $file 2>/dev/null))
      {
	  chomp ($cksum);
	  my ($sum, $f) = split(/\s+/, $cksum);
	  $fileinfo{$fname}{CHECKSUM} = "MD5:$sum";
      }

      $fileinfo{$fname}{SIZE} = -s $file;
      $fileinfo{$fname}{DISTRIBUTION} = $distribution;
    }
  }

  # Update the database
  my $stmt = &dbprep ($dbh, qq{
	insert into t_agent_version
	(node, agent, time_update,
	 filename, filesize, checksum,
	 release, revision, tag)
	values
	(:node, :agent, :now,
	 :filename, :filesize, :checksum,
	 :release, :revision, :tag)});
	
  &dbexec ($dbh, qq{
	delete from t_agent_version
	where node = :node and agent = :me},
	":node" => $self->{ID_MYNODE},
	":me" => $self->{ID_AGENT});

  foreach my $fname (keys %fileinfo)
  {
    &dbbindexec ($stmt,
		     ":now" => $now,
		     ":node" => $self->{ID_MYNODE},
		     ":agent" => $self->{ID_AGENT},
		     ":filename" => $fname,
		     ":filesize" => $fileinfo{$fname}{SIZE},
		     ":checksum" => $fileinfo{$fname}{CHECKSUM},
		     ":release" => $fileinfo{$fname}{DISTRIBUTION},
		     ":revision" => $fileinfo{$fname}{REVISION},
		     ":tag" => $fileinfo{$fname}{STICKY});
  }

  $dbh->commit ();
  $self->{DBH_AGENT_IDENTIFIED}{$self->{MYNODE}} = 1;
}

# Update the agent status in the database.  This identifies the
# agent as having connected recently and alive.
sub updateAgentStatus
{
  my ($self) = @_;
  my $dbh = $self->{DBH};
  my $now = &mytimeofday();
  return if ($self->{DBH_AGENT_UPDATE}{$self->{MYNODE}} || 0) > $now - 5*60;

  # Obtain my node id
  my $me = $self->{ME};
  ($self->{ID_MYNODE}) = &dbexec($dbh, qq{
	select id from t_adm_node where name = :node},
	":node" => $self->{MYNODE})->fetchrow();
  $self->Fatal("node $self->{MYNODE} not known to the database\n")
        if ! defined $self->{ID_MYNODE};

  # Check whether agent and agent status rows exist already.
  ($self->{ID_AGENT}) = &dbexec($dbh, qq{
	select id from t_agent where name = :me},
	":me" => $me)->fetchrow();
  my ($state) = &dbexec($dbh, qq{
	select state from t_agent_status
	where node = :node and agent = :agent},
    	":node" => $self->{ID_MYNODE}, ":agent" => $self->{ID_AGENT})->fetchrow();

  # Add agent if doesn't exist yet.
  if (! defined $self->{ID_AGENT})
  {
    eval
    {
      &dbexec($dbh, qq{
        insert into t_agent (id, name)
        values (seq_agent.nextval, :me)},
        ":me" => $me);
    };
    die $@ if $@ && $@ !~ /ORA-00001:/;
      ($self->{ID_AGENT}) = &dbexec($dbh, qq{
    select id from t_agent where name = :me},
    ":me" => $me)->fetchrow();
  }

  # Add agent status if doesn't exist yet.
  my ($ninbox, $npending, $nreceived, $ndone, $nbad, $noutbox) = (0) x 7;
  my $dir = $self->{DROPDIR};
     $dir =~ s|/worker-\d+$||; $dir =~ s|/+$||; $dir =~ s|/[^/]+$||;
  my $label = $self->{DROPDIR};
     $label =~ s|/worker-\d+$||; $label =~ s|/+$||; $label =~ s|.*/||;
  if ( defined($self->{LABEL}) )
  {
    if ( $label ne $self->{LABEL} )
    {
#      print "Using agent label \"",$self->{LABEL},
#	    "\" instead of derived label \"$label\"\n";
      $label = $self->{LABEL};
    }
  }
  my $wid = ($self->{DROPDIR} =~ /worker-(\d+)$/ ? "W$1" : "M");
  my $fqdn = $self->{DBH_ID_HOST};
  my $pid = $$;

  my $dirtmp = $self->{INBOX};
  foreach my $d (<$dirtmp/*>) {
    $ninbox++;
    $nreceived++ if -f "$d/go";
  }

  $dirtmp = $self->{WORKDIR};
  foreach my $d (<$dirtmp/*>) {
    $npending++;
    $nbad++ if -f "$d/bad";
    $ndone++ if -f "$d/done";
  }

  $dirtmp = $self->{OUTDIR};
  foreach my $d (<$dirtmp/*>) {
    $noutbox++;
  }

  &dbexec($dbh, qq{
	merge into t_agent_status ast
	using (select :node node, :agent agent, :label label, :wid worker_id,
	            :fqdn host_name, :dir directory_path, :pid process_id,
	            1 state, :npending queue_pending, :nreceived queue_received,
	            :nwork queue_work, :ncompleted queue_completed,
	            :nbad queue_bad, :noutgoing queue_outgoing, :now time_update
	       from dual) i
	on (ast.node = i.node and
	    ast.agent = i.agent and
	    ast.label = i.label and
	    ast.worker_id = i.worker_id)
	when matched then
	  update set
	    ast.host_name       = i.host_name,
	    ast.directory_path  = i.directory_path,
	    ast.process_id      = i.process_id,
	    ast.state           = i.state,
	    ast.queue_pending   = i.queue_pending,
	    ast.queue_received  = i.queue_received,
	    ast.queue_work      = i.queue_work,
	    ast.queue_completed = i.queue_completed,
	    ast.queue_bad       = i.queue_bad,
	    ast.queue_outgoing  = i.queue_outgoing,
	    ast.time_update     = i.time_update
	when not matched then
          insert (node, agent, label, worker_id, host_name, directory_path,
		  process_id, state, queue_pending, queue_received, queue_work,
		  queue_completed, queue_bad, queue_outgoing, time_update)
	  values (i.node, i.agent, i.label, i.worker_id, i.host_name, i.directory_path,
		  i.process_id, i.state, i.queue_pending, i.queue_received, i.queue_work,
		  i.queue_completed, i.queue_bad, i.queue_outgoing, i.time_update)},
       ":node"       => $self->{ID_MYNODE},
       ":agent"      => $self->{ID_AGENT},
       ":label"      => $label,
       ":wid"        => $wid,
       ":fqdn"       => $fqdn,
       ":dir"        => $dir,
       ":pid"        => $pid,
       ":npending"   => $ninbox - $nreceived,
       ":nreceived"  => $nreceived,
       ":nwork"      => $npending - $nbad - $ndone,
       ":ncompleted" => $ndone,
       ":nbad"       => $nbad,
       ":noutgoing"  => $noutbox,
       ":now"        => $now);

  $dbh->commit();
  $self->{DBH_AGENT_UPDATE}{$self->{MYNODE}} = $now;
}

# Now look for messages to me.  There may be many, so handle
# them in the order given, but only act on the final state.
# The possible messages are "STOP" (quit), "SUSPEND" (hold),
# "GOAWAY" (permanent stop), and "RESTART".  We can act on the
# first three commands, but not the last one, except if the
# latter has been superceded by a later message: if we see
# both STOP/SUSPEND/GOAWAY and then a RESTART, just ignore
# the messages before RESTART.
#
# When we see a RESTART or STOP, we "execute" it and delete all
# messages up to and including the message itself (a RESTART
# seen by the agent is likely indication that the manager did
# just that; it is not a message we as an agent can do anything
# about, an agent manager must act on it, so if we see it, it's
# an indicatioon the manager has done what was requested).
# SUSPENDs we leave in the database until we see a RESTART.
#
# Messages are only executed until my current time; there may
# be "scheduled intervention" messages for future.
sub checkAgentMessages
{
  my ($self) = @_;
  my $dbh = $self->{DBH};

  while (1)
  {
    my $now = &mytimeofday ();
    my ($time, $action, $keep) = (undef, 'CONTINUE', 0);
    my $messages = &dbexec($dbh, qq{
	    select time_apply, message
	    from t_agent_message
	    where node = :node and agent = :me
	    order by time_apply asc},
	    ":node" => $self->{ID_MYNODE},
	    ":me" => $self->{ID_AGENT});
    while (my ($t, $msg) = $messages->fetchrow())
    {
      # If it's a message for a future time, stop processing.
      last if $t > $now;

      if ($msg eq 'SUSPEND' && $action ne 'STOP')
      {
	# Hold, keep this in the database.
	($time, $action, $keep) = ($t, $msg, 1);
	$keep = 1;
      }
      elsif ($msg eq 'STOP')
      {
	# Quit.  Something to act on, and kill this message
	# and anything that preceded it.
	($time, $action, $keep) = ($t, $msg, 0);
      }
      elsif ($msg eq 'GOAWAY')
      {
	# Permanent quit: quit, but leave the message in
	# the database to prevent restarts before 'RESTART'.
	($time, $action, $keep) = ($t, 'STOP', 1);
      }
      elsif ($msg eq 'RESTART')
      {
	# Restart.  This is not something we can have done,
	# so the agent manager must have acted on it, or we
	# are processing historical sequence.  We can kill
	# this message and everything that preceded it, and
	# put us back into 'CONTINUE' state to override any
	# previous STOP/SUSPEND/GOAWAY.
	($time, $action, $keep) = (undef, 'CONTINUE', 0);
      }
      else
      {
	# Keep anything we don't understand, but no action.
	$keep = 1;
      }

      &dbexec($dbh, qq{
	delete from t_agent_message
	where node = :node and agent = :me
	  and (time_apply < :t or (time_apply = :t and message = :msg))},
      	":node" => $self->{ID_MYNODE},
	":me" => $self->{ID_AGENT},
	":t" => $t,
	":msg" => $msg)
        if ! $keep;
    }

    # Apply our changes.
    $messages->finish();
    $dbh->commit();

    # Act on the final state.
    if ($action eq 'STOP')
    {
      $self->Logmsg ("agent stopped via control message at $time");
      $self->doStop ();
      exit(0); # Still running?
    }
    elsif ($action eq 'SUSPEND')
    {
      # The message doesn't actually specify for how long, take
      # a reasonable nap to avoid filling the log files.
      $self->Logmsg ("agent suspended via control message at $time");
      $self->nap (90);
      next;
    }
    else
    {
      # Good to go.
      last;
    }
  }
}

######################################################################
# Expand a list of node patterns into node names.  This function is
# called when we don't yet know our "node identity."  Also runs the
# usual agent identification process against the database.
sub expandNodes
{
  my ($self, $require) = @_;
  my $dbh = $self->{DBH};
  my $now = &mytimeofday();
  my @result;

  # Construct a query filter for required other agents to be active
  my (@filters, %args);
  foreach my $agent ($require ? keys %$require : ())
  {
    my $var = ":agent@{[scalar @filters]}";
    push(@filters, "(a.name like ${var}n and s.time_update >= ${var}t)");
    $args{"${var}t"} = $now - $require->{$agent};
    $args{"${var}n"} = $agent;
  }
  my $filter = "";
  $filter = ("and exists (select 1 from t_agent_status s"
	     . " join t_agent a on a.id = s.agent"
	     . " where s.node = n.id and ("
	     . join(" or ", @filters) . "))")
	if @filters;

  # Now expand to the list of nodes
  foreach my $pat (@{$self->{NODES}})
  {
    my $q = &dbexec($dbh, qq{
      select id, name from t_adm_node n
      where n.name like :pat $filter
      order by name},
      ":pat" => $pat, %args);
    while (my ($id, $name) = $q->fetchrow())
    {
      $self->{NODES_ID}{$name} = $id;
      push(@result, $name);

      $self->{MYNODE} = $name;
      $self->updateAgentStatus();
      $self->identifyAgent();
      $self->checkAgentMessages();
      $self->{MYNODE} = undef;
    }
  }

  return @result;
}

# Construct a database query for destination node pattern
sub myNodeFilter
{
  my ($self, $idfield) = @_;
  my (@filter, %args);
  my $n = 1;
  foreach my $id (values %{$self->{NODES_ID}})
  {
    $args{":dest$n"} = $id;
    push(@filter, "$idfield = :dest$n");
    ++$n;
  }

  unless (@filter) {
      $self->Fatal("myNodeFilter() matched no nodes");
  }

  my $filter =  "(" . join(" or ", @filter) . ")";
  return ($filter, %args);
}

# Construct database query parameters for ignore/accept filters.
sub otherNodeFilter
{
  my ($self, $idfield) = @_;
  my $now = &mytimeofday();
  if (($self->{IGNORE_NODES_IDS}{LAST_CHECK} || 0) < $now - 300)
  {
    my $q = &dbprep($self->{DBH}, qq{
        select id from t_adm_node where name like :pat});

    my $index = 0;
    foreach my $pat (@{$self->{IGNORE_NODES}})
    {
      &dbbindexec($q, ":pat" => $pat);
      while (my ($id) = $q->fetchrow())
      {
        $self->{IGNORE_NODES_IDS}{MAP}{++$index} = $id;
      }
    }

    $index = 0;
    foreach my $pat (@{$self->{ACCEPT_NODES}})
    {
      &dbbindexec($q, ":pat" => $pat);
      while (my ($id) = $q->fetchrow())
      {
        $self->{ACCEPT_NODES_IDS}{MAP}{++$index} = $id;
      }
    }

    $self->{IGNORE_NODES_IDS}{LAST_CHECK} = $now;
  }

  my (@ifilter, @afilter, %args);
  while (my ($n, $id) = each %{$self->{IGNORE_NODES_IDS}{MAP}})
  {
    $args{":ignore$n"} = $id;
    push(@ifilter, "$idfield != :ignore$n");
  }
  while (my ($n, $id) = each %{$self->{ACCEPT_NODES_IDS}{MAP}})
  {
    $args{":accept$n"} = $id;
    push(@afilter, "$idfield = :accept$n");
  }

  my $ifilter = (@ifilter ? join(" and ", @ifilter) : "");
  my $afilter = (@afilter ? join(" or ", @afilter) : "");
  if (@ifilter && @afilter)
  {
    return ("and ($ifilter) and ($afilter)", %args);
  }
  elsif (@ifilter)
  {
    return ("and ($ifilter)", %args);
  }
  elsif (@afilter)
  {
    return ("and ($afilter)", %args);
  }
  return ("", ());
}

sub _start
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  $self->Logmsg("starting (session ",$session->ID,")");
  $self->preprocess( $kernel, $session );
  if ( $self->can('_poe_init') )
  {
    $kernel->state('_poe_init',$self);
    $kernel->yield('_poe_init');
  }
  $kernel->yield('_process');
  $kernel->yield('_maybeStop');
  $self->Logmsg("has successfully initialised");
}

sub _process
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($start,$t,$t1);
  print $self->Dbgmsg("starting '_process'") if $self->{DEBUG};

  if ( exists($self->{stats}{process}) )
  {
    $t = time;
    if ( defined($t1 = $self->{stats}{process}{_offCPU}) )
    {
      push @{$self->{stats}{process}{offCPU}}, $t - $t1;
      undef $self->{stats}{process}{_offCPU};
    }
    $self->{stats}{process}{count}++;
    $start = time;
  }

  $self->process();

  if ( exists($self->{stats}{process}) )
  {
    $t = time;
    push @{$self->{stats}{process}{onCPU}}, $t - $start;
    $self->{stats}{process}{_offCPU} = $t;
  }

  print $self->Dbgmsg("ending '_process'") if $self->{DEBUG};
  $kernel->delay_set('_process',$self->{WAITTIME}) if $self->{WAITTIME};
}

sub _maybeStop
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];

  print $self->Dbgmsg("starting '_maybeStop'") if $self->{VERBOSE} >= 3;
  $self->{stats}{maybeStop}++ if exists $self->{stats}{maybeStop};;

  $self->maybeStop();
  print $self->Dbgmsg("ending '_maybeStop'") if $self->{VERBOSE} >= 3;
  $kernel->delay_set('_maybeStop', 1);
}

sub _stop
{
  my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
  print $self->Hdr, "ending, for lack of work...\n";
}

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

1;
