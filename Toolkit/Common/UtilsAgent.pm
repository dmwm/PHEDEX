# Initialise drop-box-based agent.
sub initDropBoxAgent
{
    die "$me: fatal error: no drop box directory given\n" if ! $dropdir;
    die "$me: fatal error: non-existent drop box directory\n" if ! -d $dropdir;
    foreach my $dir (@nextdir) {
      die "$me: fatal error: no downstream drop box\n" if ! -d $dir;
    }

    $inbox = "$dropdir/inbox";
    $workdir = "$dropdir/work";
    $outdir = "$dropdir/outbox";
    $stopflag = "$dropdir/stop";
    $pidfile = "$dropdir/pid";

    if (-f $stopflag) {
	&warn("removing (old?) stop flag");
	unlink ($stopflag);
    }

    if (-f $pidfile) {
	my $oldpid = `cat $pidfile`;
	chomp ($oldpid);
	&warn("removing (old?) pidfile ($oldpid)");
	unlink ($pidfile);
    }

    (open(PID, "> $pidfile") && print(PID "$$\n") && close(PID))
	|| die "$me: fatal error: cannot write to $pidfile: $!\n";

    -d $inbox || mkdir $inbox
	|| die "$me: fatal error: cannot create inbox: $!\n";
    -d $workdir || mkdir $workdir
	|| die "$me: fatal error: cannot create work directory: $!\n";
    -d $outdir || mkdir $outdir
	|| die "$me: fatal error: cannot create outbox directory: $!\n";
}

# Check if the agent should stop.  If the stop flag is set, cleans up
# and quits.  Otherwise returns.
sub maybeStop
{
    # Check for the stop flag file.  If it exists, quit: remove the
    # pidfile and the stop flag and exit.
    return if ! -f $stopflag;

    &note("exiting from stop flag");
    unlink($pidfile);
    unlink($stopflag);
    &stop() if defined (&stop);
    exit (0);
}

# Look for pending drops in inbox.
sub readInbox
{
    die "$me: fatal error: no inbox directory given\n" if ! $inbox;

    # Scan the inbox.  If this fails, file an alert but keep going,
    # the problem might be transient (just sleep for a while).
    my @files = ();
    &alert("cannot list inbox: $!")
	if (! &getdir($inbox, \@files));

    # Check for junk
    foreach my $f (@files)
    {
	# Make sure we like it.
	if (! -d "$inbox/$f")
	{
	    &alert("junk ignored in inbox: $f") if ! exists $junk{$f};
	    $junk{$f} = 1;
        }
	else
	{
	    delete $junk{$f};
        }
    }

    # Return those that are ready
    return grep(-f "$inbox/$_/go", @files);
}

# Look for pending tasks in the work directory.
sub readPending
{
    die "$me: fatal error: no work directory given\n" if ! $workdir;

    # Scan the work directory.  If this fails, file an alert but keep
    # going, the problem might be transient.
    my @files = ();
    &alert("cannot list workdir: $!")
	if (! getdir($workdir, \@files));

    return @files;
}

# Look for tasks waiting for transfer to next agent.
sub readOutbox {
    die "$me: fatal error: no outbox directory given\n" if ! $outdir;

    # Scan the outbox directory.  If this fails, file an alert but keep
    # going, the problem might be transient.
    my @files = ();
    &alert("cannot list outdir: $!")
	if (! getdir ($outdir, \@files));

    return @files;
}

# Rename a drop to a new name
sub renameDrop
{
    my ($drop, $newname) = @_;
    &mv ("$workdir/$drop", "$workdir/$newname")
        || do { &alert ("can't rename $drop to $newname"); return 0; };
    return 1;
}

# Transfer the drop to the next agent
sub relayDrop
{
    my $drop = shift;

    # Move to output queue if not done yet
    if (-d "$workdir/$drop")
    {
        &mv ("$workdir/$drop", "$outdir/$drop") || return;
    }

    # Check if we've already successfully copied this one downstream.
    # If so, just nuke it; manual recovery is required to kick the
    # downstream ones forward.
    if (-f "$outdir/$drop/gone") {
	&rmtree ("$outdir/$drop");
	return;
    }

    # Clean up our markers
    &rmtree("$outdir/$drop/go");
    &rmtree("$outdir/$drop/gone");
    &rmtree("$outdir/$drop/bad");
    &rmtree("$outdir/$drop/done");

    # Copy to the next ones.  We want to be careful with the ordering
    # here -- we want to copy the directory exactly once, ever.  So
    # execute in an order that is safe even if we get interrupted.
    if (scalar @nextdir == 0)
    {
	&rmtree ("$outdir/$drop");
    }
    elsif (scalar @nextdir == 1)
    {
	-d "$nextdir[0]/inbox"
	    || mkdir "$nextdir[0]/inbox"
	    || -d "$nextdir[0]/inbox"
	    || return &alert("cannot create $nextdir[0]/inbox: $!");

	&mv ("$outdir/$drop", "$nextdir[0]/inbox/$drop")
	    || return &alert("failed to copy $drop to $nextdir[0]/$drop: $!");
	&touch ("$nextdir[0]/inbox/$drop/go")
	    || &alert ("failed to make $nextdir[0]/inbox/$drop go");

	&rmtree ("$outdir/$drop");
    }
    else
    {
        foreach my $dir (@nextdir)
        {
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
	    my $status = &runcmd  ("cp", "-Rp", "$outdir/$drop", "$dir/inbox/$drop");
	    return &alert ("can't copy $drop to $dir/inbox: $status") if $status;

	    # Mark it almost ready to go
	    &touch("$dir/inbox/$drop/go-pending");
        }

        # Now mark myself gone downstream so we won't try copying again
        # (FIXME: error checking?)
        &touch ("$outdir/$drop/gone");

        # All downstream versions copied safely now.  Now really let them
        # go onwards.  If this fails, it's not fatal because someone can
        # still manually fix them to be in ready state.  We haven't lost
        # anything.  (FIXME: avoidable?)
        foreach my $dir (@nextdir) {
	    &mv("$dir/inbox/$drop/go-pending", "$dir/inbox/$drop/go");
        }

        # Now junk it here
        &rmtree("$outdir/$drop");
    }
}

# Check what state the drop is in and indicate if it should be
# processed by agent-specific code.
sub inspectDrop
{
    my $drop = shift;

    if (! -d "$workdir/$drop")
    {
	&alert("$drop is not a pending task");
	return 0;
    }

    if (-f "$workdir/$drop/bad")
    {
	&alert("$drop marked bad, skipping") if ! exists $bad{$drop};
	$bad{$drop} = 1;
	return 0;
    }

    if (! -f "$workdir/$drop/go")
    {
	&alert("$drop is incomplete!");
	return 0;
    }

    if (-f "$workdir/$drop/done")
    {
	&relayDrop ($drop);
	return 0;
    }

    return 1;
}

# Mark a drop bad.
sub markBad
{
    my $drop = shift;
    &touch("$workdir/$drop/bad");
    &logmsg("stats: $drop @{[&formatElapsedTime]} failed");
}

# Manage work queue.  If there are previously pending work, finish
# it, otherwise look for and process new inbox drops.
sub process
{
    &initDropBoxAgent();
    &init() if defined (&init);

    while (1)
    {
	my $drop;

	# Check for new inputs.  Move inputs to pending work queue.
	&maybeStop();
	foreach $drop (&readInbox ())
	{
	    &maybeStop();
	    if (! &mv ("$inbox/$drop", "$workdir/$drop"))
	    {
		# Warn and ignore it, it will be returned again next time around
		&alert("failed to move job '$drop' to pending queue: $!");
	    }
	}

	# Check for pending work to do.
	&maybeStop();
	my @pending = &readPending ();
	my $npending = scalar (@pending);
	foreach $drop (@pending)
	{
	    &maybeStop();
	    &processDrop ($drop, --$npending);
	}

	# Check for drops waiting for transfer to the next agent.
	&maybeStop();
	foreach $drop (&readOutbox())
	{
	    &maybeStop();
	    &relayDrop ($drop);
	}

	# Wait a little while.
	&maybeStop();
	if (defined (&idle)) {
	    &idle ($waittime, @pending);
	} else {
	    sleep ($waittime);
	}
    }
}

1;
