package UtilsRFIO; use strict; require Exporter; use vars '@EXPORT';
@EXPORT = qw(rfstat rfmkpath rflist rfsubdirs rffiles rfcp rfrm rfrmall rfcpmany);

# Check if a RFIO file exists.  Returns undef if the file
# doesn't exist at all, otherwise the protection string.
sub rfstat
{
    my ($name) = @_;
    my $mode = undef;
    open (RFCMD, "rfstat $name 2>/dev/null |") || die "cannot run rfstat";
    while (<RFCMD>)
    {
	if (/^Protection\s*:\s*(\S+)\s+/)
	{
	    $mode = $1;
	    last;
	}
    }
    close (RFCMD);
    return $mode;
}

# Make RFIO directory tree if it doesn't exist yet.  Returns
# non-zero on success, zero on failure (either rfmkdir failed
# or a non-directory by that name already exists).
sub rfmkpath
{
    my ($name) = @_;
    my $status = &rfstat ($name);
    if (! $status) {
	return !&runcmd ("rfmkdir", "-p", $name);
    } elsif ($status =~ /^d/) {
	return 1;
    } else {
	return 0;
    }
}

# List the contents of a RFIO directory with a criteria.
sub rflist
{
    my ($dir, $rx, @rejects) = @_;
    my @list = ();

    if (open (DIR, "rfdir $dir 2>/dev/null |"))
    {
	while (<DIR>)
	{
	    next if !/$rx/;
	    my @words = split(/\s+/, $_);
	    my $name = $words[$#words];
	    next if grep ($name eq $_, @rejects);
	    push (@list, $name);
        }
	close (DIR);
    }
    return @list;
}

# Return the subdirectories of a RFIO directory.
sub rfsubdirs
{ return &rflist ($_[0], qr/^d/, ".", ".."); }

# Return the files in a RFIO directory.
sub rffiles
{ return &rflist ($_[0], qr/^-/); }

# Copy a file to or from RFIO.  Returns non-zero on success.
sub rfcp
{ return !&runcmd("rfcp", @_); }

# Remove a RFIO file.  Returns non-zero on success.
sub rfrm
{ return !&runcmd("rfrm", @_); }

# Remove a RFIO directory.  Returns non-zero on success.
sub rfrmdir
{ return !&runcmd("rfrmdir", @_); }

# Remove a RFIO directory and all files in it.  Returns non-zero on success.
sub rfrmall
{
    my ($dir) = @_;

    return 1 if ! &rfstat ($dir);
    foreach my $file (&rffiles ($dir))
    {
        for (my $attempts = 1; $attempts <= 10; ++$attempts)
        {
            print "removing $dir/$file\n";
            last if &rfrm ("$dir/$file");
            &alert ("failed to remove $dir/$file (attempt $attempts), trying again in 10s");
            sleep (10);
        }
    }

    return &rfrmdir ($dir);
}

# Copy many files in parallel
sub rfcpstart
{
    my ($from, $to) = @_;
    my $pid = fork ();

    # Return child pid in parent.  In case of failure, sleep for
    # a while and indicate to the caller to retry.
    do { sleep (10); return undef; } if $pid == -1;
    return $pid if $pid;

    # Child.
    my @args = ("rfcp", $from, $to);
    exec { $args[0] } @args;
    die "Cannot start rfcp: $!\n";
}

sub rfcpmany
{
    use POSIX;
    my ($njobs, %files) = @_;
    my @workers = (0) x $njobs;
    my %pending = ();
    my %done = ();
    my $errors = 0;

    while ((! $errors && keys %files) || grep ($_, @workers))
    {
	for (my $i = 0; $i <= $#workers; ++$i)
	{
	    if (! $workers[$i] && ! $errors && keys %files)
	    {
		my $from = (keys %files)[0];
		my $to = $files{$from};
		my $new = &rfcpstart ($from, $to);
		next if ! defined $new;

		delete $files{$from};
		$workers[$i] = $new;
		$pending{$new} = $from;
	    }
	    elsif ($workers[$i] && waitpid ($workers[$i], WNOHANG) > 0)
	    {
		$done{$pending{$workers[$i]}} = $?;
		$workers[$i] = 0;
		$errors++ if $?;
	    }
	}

	# Sleep a bit to avoid going into busy loop.
	select (undef, undef, undef, 0.1);
    }

    return %done;
}

1;
