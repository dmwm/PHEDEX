sub usage
{
    print STDERR @_;
    open (ME, "< $0")
        && print(STDERR map { s/^\#\#H ?//; $_ } grep (/^\#\#H/, <ME>))
	&& close(ME);
    exit(1);
}

# Read the pattern files.  Reads each file, splits it at white
# space, and returns the list of all patterns in all the files.
sub readPatterns
{
    my (@files) = @_;
    my @patterns = ();
    foreach my $file (@files)
    {
	if ($file =~ /^\@(.*)/) {
	    open (FILE, "< $1") or die "$1: cannot read\n";
	    push(@patterns, map { chomp; split(/\s+/, $_); } <FILE>);
	    close (FILE);
	} else {
	    push(@patterns, $file);
	}
    }

    return @patterns;
}

# Expand patterns according to the operating mode.  Returns the
# list of all dataset.owner pairs that match the mode and the
# input patterns.
sub expandPatterns 
{
    my ($mode, @patterns) = @_;

    # If "-a" option, the patterns are really assignment numbers
    return @patterns if $mode eq 'a';

    # If "-f" or "-p" option, the patterns are dataset.owners.
    # For "-p", expand to the matching pairs.  For "-f", expand
    # the resulting list by navigating backwards using assignment
    # InputOwnerName in the DST/Digi/Hits chain.

    open(LIST, "./RefDBList @patterns |")
	or die "cannot run RefDBList: $!\n";
    @patterns = map { chomp; $_ } <LIST>;
    close (LIST);

    return @patterns if mode eq 'p';

    # FIXME: get assignment info, and walk to InputOwnerName
    return @patterns;
}

# Expand patterns to assignment ids
sub expandAssignments
{
    my @patterns = @_;
    my @assignments = ();

    open(LIST, "./RefDBAssignments @patterns |") 
	or die "cannot run RefDBAssignments: $!\n";
    push (@assignments, map { chomp; split (/\s+/, $_) } <LIST>);
    close (LIST);

    return @assignments;
}

1;
