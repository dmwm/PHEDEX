# Read job checksum data: lines of "CHECKSUM SIZE FILE".
sub readChecksumData
{
    my ($drop, $file) = @_;
    if (! open (IN, "< $file"))
    {
	&alert ("cannot read checksum file $file: $!");
	&markBad ($drop);
	return ();
    }

    my @result = ();
    while(<IN>)
    {
	chomp;

	# Skip empty lines
	next if /^$/;

	# Process matching lines (<checksum> <size> <filename>)
	if (/^\d+ \d+ \S+$/)
	{
	    push(@result, [ split(/\s+/, $_) ]);
	}
	else
	{
	    # Complain about bad lines
	    &alert("unrecognised checksum line: $file:$.");
	    &markBad ($drop);
	    last;
	}
    }

    close (IN);
    return @result;
}

# Read catalog data.  There's no easy way to map files to guids.  The
# only tools available at present are python scripts, but as the
# interface is changing between POOL 1.5.x and 1.6.x, we'd rather not
# bother.  Instead just read the XML and extract the info we need.
# Not terribly robust groping behind the backs, for now is the most
# reliable and simple way to do it.
#
# FIXME: replace by a query call when POOL provides a suitable tool.
sub readXMLCatalog
{
    my ($drop, $file) = @_;
    if (! open (IN, "< $file"))
    {
	&alert("cannot read catalog file $file: $!");
	&markBad ($drop);
	return {};
    }

    my $result = {};
    while(<IN>)
    {
	chomp;

	if (m|<File ID="([-0-9A-Fa-f]+)">|)
	{
	    my ($guid, $frag) = ($1, { GUID => $1, TEXT => "$_\n" });
	    while (<IN>)
	    {
		$frag->{TEXT} .= $_;
		chomp;

		if (m|<pfn\s.*\sname="(.*)"/>|) {
		    push (@{$frag->{PFN}}, $1);
		} elsif (m|<lfn\sname="(.*)"/>|) {
		    push (@{$frag->{LFN}}, $1);
		} elsif (m|<metadata\s+att_name="(.*)"\s+att_value="(.*)"/>|) {
		    $frag->{META}{$1} = $2;
		    $frag->{GROUP} = $2 if ($1 eq 'jobid');
		} elsif (m|</File>|) {
		    last;
		}
	    }

	    if (scalar @{$frag->{PFN}} != 1
		|| scalar @{$frag->{LFN}} != 1
		|| ! $guid)
	    {
		&alert("cannot understand catalog $file");
		&markBad ($drop);
		$result = {};
		last;
	    }
	    elsif (exists $result->{$guid})
	    {
		&alert("catalog $file with duplicate guid $guid");
		&markBad ($drop);
		$result = {};
		last;
	    }
	    else
	    {
		$result->{$guid} = $frag;
	    }
	}
    }

    close (IN);

    if (! keys %$result)
    {
	&alert("no guid mappings found in catalog $file");
	&markBad ($drop);
    }

    return $result;
}

1;
