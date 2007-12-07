package PHEDEX::Core::Agent;

=head1 NAME

PHEDEX::Core::Agent - a drop-in replacement for Toolkit/UtilsAgent, with a 
few enhancements

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::JobManager';
use POSIX;
use File::Path;
use PHEDEX::Core::Command;
use PHEDEX::Core::Logging;
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
	  JUNK		=> undef,
	  BAD		=> undef,
	  STARTTIME	=> undef,
	  NWORKERS	=> 0,
	  WORKERS	=> undef,
	  CONFIG_FILE	=> $ENV{PHEDEX_CONFIG_FILE},
	  LABEL		=> $ENV{PHEDEX_AGENT_LABEL},
	  ENVIRONMENT	=> undef,
	  AGENT		=> undef,
	);

our @array_params = qw / STARTTIME NODES IGNORE_NODES ACCEPT_NODES /;
our @hash_params  = qw / BAD JUNK /;
our @required_params = qw / DROPDIR DBCONFIG MYNODE /;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = $class->SUPER::new(@_);

    my %args = (@_);
    my $me = $0; $me =~ s|.*/||;

    $args{ME} = $me;

#   Retrieve the agent environment, if I can.
    my ($config,$cfg,$label,$key,$val);
    $config = $args{CONFIG_FILE} || $params{CONFIG_FILE};
    $label  = $args{LABEL}       || $params{LABEL};
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
        $params{$k} = $v;
      }

#     Some parameters are derived from the environment
      if ( $self->{AGENT} && $self->{ENVIRONMENT} )
      {
        foreach ( qw / DROPDIR LOGFILE PIDFILE / )
        {
          my $k = $self->{AGENT}->$_();
          $params{$_} = $self->{ENVIRONMENT}->getExpandedString($k);
        }
      }
    }

#   Now set the %args hash, from environment or params if not the command-line
    foreach $key ( keys %params )
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
      $args{$key} = $params{$key};
    }


    while (my ($k, $v) = each %args)
    { $self->{$k} = $v unless defined $self->{$k}; }

#   Basic validation: Explicitly call the base method to validate only the
#   core agent. This will be called again in the 'process' method, on the
#   derived agent. No harm in that!
    die "$me: Failed validation, exiting\n"
	if PHEDEX::Core::Agent::isInvalid( $self );

#   Beyond basic validation, need to check that some parameters are in fact
#   existing directories, and derive other parameters from them.
    die "$me: fatal error: non-existent drop box directory \"$self->{DROPDIR}\"\n"
	 if ! -d $self->{DROPDIR};
    $self->{INBOX}    = $self->{DROPDIR} . 'inbox'  unless $self->{INBOX};
    $self->{OUTDIR}   = $self->{DROPDIR} . 'outbox' unless $self->{OUTDIR};
    $self->{PIDFILE}  = $self->{DROPDIR} . 'pid'    unless $self->{PIDFILE};
    $self->{STOPFLAG} = $self->{DROPDIR} . 'stop'   unless $self->{STOPFLAG};
    $self->{WORKDIR}  = $self->{DROPDIR} . 'work'   unless $self->{WORKDIR};

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

    foreach ( qw / INBOX WORKDIR OUTDIR / )
    {
      -d $self->{$_} || mkdir $self->{$_};
      -d $self->{$_} || die
	    "$me: fatal error: cannot create $_ directory \"$self->{$_}\"\n";
    }

    bless $self, $class;
    # Daemonise, write pid file and redirect output.
    $self->daemon($me);
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
    # Open the pid file.
    open(PIDFILE, "> $self->{PIDFILE}")
	|| die "$me: fatal error: cannot write to $self->{PIDFILE}: $!\n";

    # Fork once to go to background
    die "failed to fork into background: $!\n"
	if ! defined ($pid = fork());
    exit(0) if $pid;

    # Make a new session
    die "failed to set session id: $!\n"
	if ! defined setsid();

    # Fork another time to avoid reacquiring a controlling terminal
    die "failed to fork into background: $!\n"
	if ! defined ($pid = fork());
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
this method.

=cut
sub isInvalid
{
  my $self = shift;
  my %h = @_;
  @{$h{REQUIRED}} = @required_params unless $h{REQUIRED};

  my $errors = 0;
  foreach ( @{$h{REQUIRED}} )
  {
   next if defined $self->{$_};
    $errors++;
    warn "Required parameter \"$_\" not defined!\n";
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
		&logmsg ("worker $i ($new) started");
	    } else {
	        &logmsg ("worker $i ($old) stopped, restarted as $new");
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
    &note ("stopping worker threads");
    &touch (@stopflags);
    while (scalar @workers)
    {
	my $pid = waitpid (-1, 0);
	@workers = grep ($pid ne $_, @workers);
	&logmsg ("child process $pid exited, @{[scalar @workers]} workers remain") if $pid > 0;
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
    &note("exiting from stop flag");
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
    &alert("cannot list inbox: $!")
	if (! &getdir($self->{INBOX}, \@files));

    # Check for junk
    foreach my $f (@files)
    {
	# Make sure we like it.
	if (! -d "$self->{INBOX}/$f")
	{
	    &alert("junk ignored in inbox: $f") if ! exists $self->{JUNK}{$f};
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
    &alert("cannot list workdir: $!")
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
    &alert("cannot list outdir: $!")
	if (! getdir ($self->{OUTDIR}, \@files));

    return @files;
}

# Rename a drop to a new name
sub renameDrop
{
    my ($self, $drop, $newname) = @_;
    &mv ("$self->{WORKDIR}/$drop", "$self->{WORKDIR}/$newname")
        || do { &alert ("can't rename $drop to $newname"); return 0; };
    return 1;
}

# Utility to undo from failed scp bridge operation
sub scpBridgeFailed
{
    my ($msg, $remote) = @_;
    # &runcmd ("ssh", $host, "rm -fr $remote");
    &alert ($msg);
    return 0;
}

sub scpBridgeDrop
{
    my ($source, $target) = @_;

    return &scpBridgeFailed ("failed to chmod $source", $target)
        if ! chmod(0775, "$source");

    return &scpBridgeFailed ("failed to copy $source", $target)
        if &runcmd ("scp", "-rp", "$source", "$target");

    return &scpBridgeFailed ("failed to copy /dev/null to $target/go", $target)
        if &runcmd ("scp", "/dev/null", "$target/go"); # FIXME: go-pending?

    return 1;
}

# Utility to undo from failed rfio bridge operation
sub rfioBridgeFailed
{
    my ($msg, $remote) = @_;
    &rfrmall ($remote) if $remote;
    &alert ($msg);
    return 0;
}

sub rfioBridgeDrop
{
    my ($source, $target) = @_;
    my @files = <$source/*>;
    do { &alert ("empty $source"); return 0; } if ! scalar @files;

    return &rfioBridgeFailed ("failed to create $target")
        if ! &rfmkpath ($target);

    foreach my $file (@files)
    {
        return &rfioBridgeFailed ("failed to copy $file to $target", $target)
            if ! &rfcp ("$source/$file", "$target/$file");
    }

    return &rfioBridgeFailed ("failed to copy /dev/null to $target", $target)
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
	    || return &alert("cannot create $self->{NEXTDIR}[0]/inbox: $!");

	# Make sure the destination doesn't exist yet.  If it does but
	# looks like a failed copy, nuke it; otherwise complain and give up.
	if (-d "$self->{NEXTDIR}[0]/inbox/$drop"
	    && -f "$self->{NEXTDIR}[0]/inbox/$drop/go-pending"
	    && ! -f "$self->{NEXTDIR}[0]/inbox/$drop/go") {
	    &rmtree ("$self->{NEXTDIR}[0]/inbox/$drop")
        } elsif (-d "$self->{NEXTDIR}[0]/inbox/$drop") {
	    return &alert("$self->{NEXTDIR}[0]/inbox/$drop already exists!");
	}

	&mv ("$self->{OUTDIR}/$drop", "$self->{NEXTDIR}[0]/inbox/$drop")
	    || return &alert("failed to copy $drop to $self->{NEXTDIR}[0]/$drop: $!");
	&touch ("$self->{NEXTDIR}[0]/inbox/$drop/go")
	    || &alert ("failed to make $self->{NEXTDIR}[0]/inbox/$drop go");
    }
    else
    {
        foreach my $dir (@{$self->{NEXTDIR}})
        {
	    if ($dir =~ /^scp:/) {
		&scpBridgeDrop ("$self->{OUTDIR}/$drop", "$dir/inbox/$drop");
		next;
	    } elsif ($dir =~ /^rfio:/) {
		&rfioBridgeDrop ("$self->{OUTDIR}/$drop", "$dir/inbox/$drop");
		next;
	    }

	    # Local.  Create destination inbox if necessary.
	    -d "$dir/inbox"
	        || mkdir "$dir/inbox"
	        || -d "$dir/inbox"
	        || return &alert("cannot create $dir/inbox: $!");

	    # Make sure the destination doesn't exist yet.  If it does but
	    # looks like a failed copy, nuke it; otherwise complain and give up.
	    if (-d "$dir/inbox/$drop"
	        && -f "$dir/inbox/$drop/go-pending"
	        && ! -f "$dir/inbox/$drop/go") {
	        &rmtree ("$dir/inbox/$drop")
            } elsif (-d "$dir/inbox/$drop") {
	        return &alert("$dir/inbox/$drop already exists!");
	    }

	    # Copy to the next stage, preserving everything
	    my $status = &runcmd  ("cp", "-Rp", "$self->{OUTDIR}/$drop", "$dir/inbox/$drop");
	    return &alert ("can't copy $drop to $dir/inbox: $status") if $status;

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
	&alert("$drop is not a pending task");
	return 0;
    }

    if (-f "$self->{WORKDIR}/$drop/bad")
    {
	&alert("$drop marked bad, skipping") if ! exists $self->{BAD}{$drop};
	$self->{BAD}{$drop} = 1;
	return 0;
    }

    if (! -f "$self->{WORKDIR}/$drop/go")
    {
	&alert("$drop is incomplete!");
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
    &logmsg("stats: $drop @{[&formatElapsedTime($self->{STARTTIME})]} failed");
}

=head2 processDrop

I have no idea what you would want to do with this either...

=cut

sub processDrop
{}

# Manage work queue.  If there are previously pending work, finish
# it, otherwise look for and process new inbox drops.
sub process
{

  my $self = shift;

  # Initialise subclass.
  $self->init();
  # Validate the object!
  die "Agent ",$self->{ME}," failed validation\n" if $self->isInvalid();
  $self->initWorkers();

  # Restore signals.  Oracle apparently is in habit of blocking them.
  $SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub { $self->doStop() };

  # Work.
  while (1)
  {
    my $drop;

    # Check for new inputs.  Move inputs to pending work queue.
    $self->maybeStop();
    foreach $drop ($self->readInbox ())
    {
      $self->maybeStop();
      if (! &mv ("$self->{INBOX}/$drop", "$self->{WORKDIR}/$drop"))
      {
	# Warn and ignore it, it will be returned again next time around
	&alert("failed to move job '$drop' to pending queue: $!");
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
    $self->idle (@pending);
  }
}

# Wait between scans
sub idle
{
    my $self = shift;
    $self->nap ($self->{WAITTIME});
}

# Sleep for a time, checking stop flag every once in a while.
sub nap
{
    my ($self, $time) = @_;
    my $target = &mytimeofday () + $time;
    do { $self->maybeStop(); sleep (1); } while (&mytimeofday() < $target);
}

1;
