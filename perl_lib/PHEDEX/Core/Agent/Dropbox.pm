package PHEDEX::Core::Agent::Dropbox;

use strict;
use warnings;
use POSIX;
use File::Path;
use File::Basename;
use PHEDEX::Core::Command;

#our @required_params = qw / DROPDIR /;
#our @writeable_dirs  = qw / DROPDIR INBOX WORKDIR OUTBOX /;
#our @writeable_files = qw / LOGFILE PIDFILE /; #/ required global arrays

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $agentLite = shift;
  my $self = {};

  no warnings 'redefine';
  *PHEDEX::Core::Agent::cleanDropbox = \&PHEDEX::Core::Agent::Dropbox::cleanDropbox;
  *PHEDEX::Core::Agent::processIdle = \&PHEDEX::Core::Agent::Dropbox::processIdle;
  if ( $agentLite->{LOAD_DROPBOX_WORKDIRS} ) {
    *PHEDEX::Core::Agent::readInbox = \&PHEDEX::Core::Agent::Dropbox::readInbox;
    *PHEDEX::Core::Agent::readPending = \&PHEDEX::Core::Agent::Dropbox::readPending;
    *PHEDEX::Core::Agent::readOutbox = \&PHEDEX::Core::Agent::Dropbox::readOutbox;
    *PHEDEX::Core::Agent::renameDrop = \&PHEDEX::Core::Agent::Dropbox::renameDrop;
    *PHEDEX::Core::Agent::relayDrop = \&PHEDEX::Core::Agent::Dropbox::relayDrop;
    *PHEDEX::Core::Agent::inspectDrop = \&PHEDEX::Core::Agent::Dropbox::inspectDrop;
    *PHEDEX::Core::Agent::markBad = \&PHEDEX::Core::Agent::Dropbox::markBad;
    *PHEDEX::Core::Agent::processInbox = \&PHEDEX::Core::Agent::Dropbox::processInbox;
    *PHEDEX::Core::Agent::processOutbox = \&PHEDEX::Core::Agent::Dropbox::processOutbox;
    *PHEDEX::Core::Agent::processWork = \&PHEDEX::Core::Agent::Dropbox::processWork;
  }

  bless $self, $class;

# Before basic validation, we need to derive a few other parameters.
  $self->{LOAD_DROPBOX_WORKDIRS} = 0; # yes, self! Avoid cluttering $agentLite
  if ( defined($agentLite->{LOAD_DROPBOX_WORKDIRS}) ) {
    $self->{LOAD_DROPBOX_WORKDIRS} = $agentLite->{LOAD_DROPBOX_WORKDIRS};
  }
  push @PHEDEX::Core::Agent::required_params, qw / DROPDIR /;
  push @PHEDEX::Core::Agent::writeable_dirs,  qw / DROPDIR /;
  $agentLite->{DROPDIR} .= '/' unless $agentLite->{DROPDIR} =~ m%\/$%;
  if ( $self->{LOAD_DROPBOX_WORKDIRS} ) {
    foreach ( qw / INBOX OUTBOX WORKDIR / ) {
      $agentLite->{$_} = $agentLite->{DROPDIR} . lc $_
        unless defined $agentLite->{$_};
      push @PHEDEX::Core::Agent::writeable_dirs, $_;
    }
  }
# Special case of TASKDIR and ARCHIVEDIR, for FileDownload and FileRemove
  foreach ( qw / TASKDIR ARCHIVEDIR / ) {
    if ( exists $agentLite->{$_} && ! defined $agentLite->{$_} ) {
      push @PHEDEX::Core::Agent::writeable_dirs, $_;
      my $val;
      ($val = $_) =~ s%DIR$%%;
      $agentLite->{$_} = $agentLite->{DROPDIR} . lc $val;
    }
  }
  if ( !$agentLite->{NODAEMON} ) {
    $agentLite->{PIDFILE}  = $agentLite->{DROPDIR} . 'pid'
      unless $agentLite->{PIDFILE};
    $agentLite->{STOPFILE} = $agentLite->{DROPDIR} . 'stop'
      unless $agentLite->{STOPFILE};
    push @PHEDEX::Core::Agent::writeable_files, qw / LOGFILE PIDFILE /;
  }

  $agentLite->{_Dropbox} = $self;
  return $self;
}

# Make a basic cleanup
sub cleanDropbox {
  my ($self,$me) = @_;

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

  if (-f $self->{STOPFILE})
  {
     print "$me: removing old stop flag $self->{STOPFILE}\n";
     unlink ($self->{STOPFILE});
  }
}

# Look for pending drops in inbox.
sub readInbox
{
    my ($self,$get_all) = @_;

    die "$self->{ME}: fatal error: no inbox directory given\n" if ! $self->{INBOX};

    # Scan the inbox.  If this fails, file an alert but keep going,
    # the problem might be transient (just sleep for a while).
    my @files = ();
    $self->Alert("cannot list inbox(".$self->{INBOX}."): $!")
	if (! getdir($self->{INBOX}, \@files));

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

    # Return those that are ready, unless we want all;
    return $get_all ? @files : grep(-f "$self->{INBOX}/$_/go", @files);
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
    die "$self->{ME}: fatal error: no outbox directory given\n" if ! $self->{OUTBOX};

    # Scan the outbox directory.  If this fails, file an alert but keep
    # going, the problem might be transient.
    my @files = ();
    $self->Alert("cannot list outdir(".$self->{OUTBOX}."): $!")
	if (! getdir ($self->{OUTBOX}, \@files));

    return @files;
}

# Rename a drop to a new name
sub renameDrop
{
    my ($self,$drop, $newname) = @_;
    &mv ("$self->{WORKDIR}/$drop", "$self->{WORKDIR}/$newname")
        || do { $self->Alert ("can't rename $drop to $newname"); return 0; };
    return 1;
}

# Transfer the drop to the next agent
sub relayDrop
{
    my ($self,$drop) = @_;
die "Someone really wants to use relayDrop???\n";
#    # Move to output queue if not done yet
#    if (-d "$self->{WORKDIR}/$drop")
#    {
#        &mv ("$self->{WORKDIR}/$drop", "$self->{OUTBOX}/$drop") || return;
#    }
#
#    # Check if we've already successfully copied this one downstream.
#    # If so, just nuke it; manual recovery is required to kick the
#    # downstream ones forward.
#    if (-f "$self->{OUTBOX}/$drop/gone") {
#	&rmtree ("$self->{OUTBOX}/$drop");
#	return;
#    }
#
#    # Clean up our markers
#    &rmtree("$self->{OUTBOX}/$drop/go");
#    &rmtree("$self->{OUTBOX}/$drop/gone");
#    &rmtree("$self->{OUTBOX}/$drop/bad");
#    &rmtree("$self->{OUTBOX}/$drop/done");
#
#    # Copy to the next ones.  We want to be careful with the ordering
#    # here -- we want to copy the directory exactly once, ever.  So
#    # execute in an order that is safe even if we get interrupted.
#    if (scalar @{$self->{NEXTDIR}} == 0)
#    {
#	&rmtree ("$self->{OUTBOX}/$drop");
#    }
#    elsif (scalar @{$self->{NEXTDIR}} == 1 && $self->{_Al}->{NEXTDIR}[0] !~ /^([a-z]+):/)
#    {
#	-d "$self->{NEXTDIR}[0]/inbox"
#	    || mkdir "$self->{NEXTDIR}[0]/inbox"
#	    || -d "$self->{NEXTDIR}[0]/inbox"
#	    || return $self->Alert("cannot create $self->{NEXTDIR}[0]/inbox: $!");
#
#	# Make sure the destination doesn't exist yet.  If it does but
#	# looks like a failed copy, nuke it; otherwise complain and give up.
#	if (-d "$self->{NEXTDIR}[0]/inbox/$drop"
#	    && -f "$self->{NEXTDIR}[0]/inbox/$drop/go-pending"
#	    && ! -f "$self->{NEXTDIR}[0]/inbox/$drop/go") {
#	    &rmtree ("$self->{NEXTDIR}[0]/inbox/$drop")
#        } elsif (-d "$self->{NEXTDIR}[0]/inbox/$drop") {
#	    return $self->Alert("$self->{NEXTDIR}[0]/inbox/$drop already exists!");
#	}
#
#	&mv ("$self->{OUTBOX}/$drop", "$self->{NEXTDIR}[0]/inbox/$drop")
#	    || return $self->Alert("failed to copy $drop to $self->{NEXTDIR}[0]/$drop: $!");
#	&touch ("$self->{NEXTDIR}[0]/inbox/$drop/go")
#	    || $self->Alert ("failed to make $self->{NEXTDIR}[0]/inbox/$drop go");
#    }
#    else
#    {
#        foreach my $dir (@{$self->{NEXTDIR}})
#        {
#	    if ($dir =~ /^scp:/ || $dir =~ /^rfio:/ ) {
#               $self->Alert("Fail, scp or rfio not supported anymore");
#               next;
#	    }
#
#	    # Local.  Create destination inbox if necessary.
#	    -d "$dir/inbox"
#	        || mkdir "$dir/inbox"
#	        || -d "$dir/inbox"
#	        || return $self->Alert("cannot create $dir/inbox: $!");
#
#	    # Make sure the destination doesn't exist yet.  If it does but
#	    # looks like a failed copy, nuke it; otherwise complain and give up.
#	    if (-d "$dir/inbox/$drop"
#	        && -f "$dir/inbox/$drop/go-pending"
#	        && ! -f "$dir/inbox/$drop/go") {
#	        &rmtree ("$dir/inbox/$drop")
#            } elsif (-d "$dir/inbox/$drop") {
#	        return $self->Alert("$dir/inbox/$drop already exists!");
#	    }
#
#	    # Copy to the next stage, preserving everything
#	    my $status = &runcmd  ("cp", "-Rp", "$self->{OUTBOX}/$drop", "$dir/inbox/$drop");
#	    return $self->Alert ("can't copy $drop to $dir/inbox: $status") if $status;
#
#	    # Mark it almost ready to go
#	    &touch("$dir/inbox/$drop/go-pending");
#        }
#
#        # Now mark myself gone downstream so we won't try copying again
#        # (FIXME: error checking?)
#        &touch ("$self->{OUTBOX}/$drop/gone");
#
#        # All downstream versions copied safely now.  Now really let them
#        # go onwards.  If this fails, it's not fatal because someone can
#        # still manually fix them to be in ready state.  We haven't lost
#        # anything.  (FIXME: avoidable?)
#        foreach my $dir (@{$self->{NEXTDIR}}) {
#	    next if $dir =~ /^([a-z]+):/; # FIXME: also handle here?
#	    &mv("$dir/inbox/$drop/go-pending", "$dir/inbox/$drop/go");
#        }
#
#        # Now junk it here
#        &rmtree("$self->{OUTBOX}/$drop");
#    }
}

# Check what state the drop is in and indicate if it should be
# processed by agent-specific code.
sub inspectDrop
{
    my ($self,$drop) = @_;

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
    my ($self,$drop) = @_;
    &touch("$self->{WORKDIR}/$drop/bad");
    $self->Logmsg("stats: $drop @{[&formatElapsedTime($self->{STARTTIME})]} failed");
}

#Process Inbox
sub processInbox
{
  my $self = shift;
  my $pmon = $self->{pmon};
  my $drop;

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
}

#Process Work
sub processWork
{
  my $self = shift;
  my $pmon = $self->{pmon};
  my $drop;

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
  return @pending;
}

#Process Outbox
sub processOutbox
{
  my $self = shift;
  my $pmon = $self->{pmon};
  my $drop;

  # Check for drops waiting for transfer to the next agent.
  $self->maybeStop();
  $pmon->State('outbox','start');
  foreach $drop ($self->readOutbox())
  {
    $self->maybeStop();
    $self->relayDrop ($drop);
  }
  $pmon->State('outbox','stop');
}

#Process Idle
sub processIdle
{
  my $self = shift;
  my @pending = @_;
  my $pmon = $self->{pmon};
  my $drop;

  # Wait a little while.
  $self->maybeStop();
  $pmon->State('idle','start');
  $self->idle (@pending);
  $pmon->State('idle','stop');
}

1;
