# Utilities for file merging.  This module provides code shared by the
# master and slave -- master can optionally do part of the slaves' work
# if there is no other work to be done.
package UtilsFunnel; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(flushFailed fetchQueuedFiles);

# Utility to log and cleanup from failed flush attempt
sub flushFailed
{
    my ($stats, $time, $msg, $dirs, $remote) = @_;

    # Try clean up RFIO file if there is one
    if ($remote)
    {
        my $attempts = 1;
        while ($attempts <= 10)
        {
	    last if &rfrm ($remote);
	    &alert ("failed to remove $remote (attempt $attempts), trying again in 10 seconds");
	    sleep (10);
	    $attempts++;
	}
    }

    # Get rid of temporary directories
    &rmtree ($dirs);

    # Log messages
    &alert ($msg);
    &logmsg ("$stats @{[&formatElapsedTime($time)]} failed");

    # Indicate failure
    return 0;
}

# Ensure all files for the queue have been fetched.
sub fetchQueueFiles
{
    my ($self, $queuedir, $data) = @_;
    my $timing = [];
    &timeStart ($timing);

    my $queue = $queuedir; $queue =~ s|.*/||;
    my $predir = "$queuedir/prefetch";
    my $filesdir = "$queuedir/files";
    my $stats = "prefetch: $queue";

    # Create upload directory if necessary
    eval { &mkpath ([$predir, $filesdir]); };
    return &flushFailed ($stats, $timing, "could not create working directories: $@",
	    		 [ $predir, $filesdir ])
	if $@;

    # Download and validate files.
    my %copy = ();
    foreach my $member (values %{$data->{MEMBERS}})
    {
	my $pfn = $member->{FILE}{PFN};
	my $lfn = $member->{FILE}{LFN};

	next if -f "$filesdir/$lfn";
	if ($self->{DRYRUN}) {
	    &touch ("$predir/$lfn");
	} else {
	    $copy{$pfn} = "$predir/$lfn";
	}
    }

    my %copied = &rfcpmany ($self->{NRFCP}, %copy);
    my @failed = grep ($copied{$_}, keys %copied);
    return &flushFailed ($stats, $timing, "failed to copy @{[scalar @failed]} files", $predir)
        if @failed;

    foreach my $member (values %{$data->{MEMBERS}})
    {
	my $pfn = $member->{FILE}{PFN};
	my $lfn = $member->{FILE}{LFN};

	next if ! -f "$predir/$lfn" && -f "$filesdir/$lfn";

	return &flushFailed ($stats, $timing, "file size mismatch for $lfn", $predir)
	    if ((stat("$predir/$lfn"))[7] != $member->{FILE}{FILESIZE});

	unlink ("$filesdir/$lfn");
	return &flushFailed ($stats, $timing, "failed to move $lfn into files",
			     [ $predir, $filesdir ])
	    if ! &mv ("$predir/$lfn", "$filesdir/$lfn");
    }

    &logmsg ("$stats @{[&formatElapsedTime($timing)]} success") if keys %copied;
    return 1;
}

1;
