package UtilsCommand; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(getdir runcmd runerror touch mv cksum output input);

# Get directory contents
sub getdir
{
    my ($dir, $files) = @_;
    my @contents = ();
    return 0 if (! (opendir(DIR, $dir)
		    && (@contents = readdir(DIR))
		    && closedir(DIR)));

    @$files = grep($_ ne '.' && $_ ne '..', @contents);
    return 1;
}

# Utilities to run commands
sub runcmd
{
    my ($cmd, @args) = @_;
    my $pid = open(SUBCMD, "|-");
    if (! defined $pid) {
	return 255;
    } elsif (! $pid) {
	(exec $cmd $cmd, @args) || exit (255);
    } else {
	return close(SUBCMD) ? 0 : $?;
    }
}

# Get exit code from a previously ran command
sub runerror
{
  my $rc	= shift;
  my $code	= $rc >> 8;
  my $signal	= $rc & 127;
  my $core	= $rc & 128;

  return ($signal ? "signal $signal" : "$code").($core ? " (core dumped)" : "");
}

# Create a file
sub touch
{
    my $now = time;
    if ($_[0] eq '-t')
    {
        use POSIX "mktime";
	shift (@_);
	my $date = shift (@_);
	my ($y,$m,$d,$hh,$mm,$ss)
	    = ($date =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\.(\d\d)/);
	$now = mktime ($ss, $mm, $hh, $d, $m-1, $y-1900, 0, 0, -1);
    }

    foreach my $file (@_)
    {
        return 0 if ! ((-f $file || (open (TOUCH, "> $file") && close(TOUCH)))
			&& utime ($now, $now, $file));
    }
    return 1;
}

# Move a file or directory (assumes single file system)
# NB: Don't use File::Copy as it seems to create new files?
sub mv
{
    my $status = &runcmd ("mv", @_);
    if ($status)
    {
	$! = 0;
	return 0;
    }
    else
    {
	return 1;
    }
}

# Checksum a file and return the output as a string.  Returns undef
# if 'cksum' invocation fails or doesn't produce expected output.
sub cksum
{
    my ($dir, $file) = @_;
    return undef if ! open(CKSUM, "cd $dir && cksum '$file' |");

    my $sawit = 0;
    my $output = "";
    while (<CKSUM>)
    {
	$output .= $_;
	$sawit = 1 if /^\d+\s+\d+\s+\S+$/;
    }
    close (CKSUM);

    return $sawit ? $output : undef;
}

# Write a file safely
sub output
{
    my ($file, $content) = @_;
    return (open (FILE, "> $file.$$")
	    && (print FILE $content)
	    && close (FILE)
	    && &mv ("$file.$$", $file));

}

# Read a file safely
sub input
{
    my ($file) = @_;
    my $content;
    return (open (FILE, "< $file")
	    && ($content = join("", <FILE>))
	    && close (FILE))
        ? $content : undef;
}

1;
