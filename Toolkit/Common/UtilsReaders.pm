package UtilsReaders; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(readChecksumData readXMLCatalogue parseXMLCatalogue parseXMLAttrs);

# Read job checksum data: lines of "CHECKSUM SIZE FILE".
sub readChecksumData
{
    my ($file) = @_;
    open (IN, "< $file") or die "cannot read checksum file $file: $!";
    my @result = ();
    while(<IN>)
    {
	chomp;

	# Skip empty lines
	next if /^$/;

	# Process matching lines (<checksum> <size> <filename>)
	if (/^-?\d+ -?\d+ \S+$/)
	{
	    push(@result, [ split(/\s+/, $_) ]);
	}
	else
	{
	    # Complain about bad lines
	    close (IN);
	    die "unrecognised checksum line: $file:$.";
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
sub readXMLCatalogue
{
    my ($file) = @_;
    open (IN, "< $file") or die "cannot read catalog file $file: $!";
    my $contents = join("", <IN>);
    close (IN) or die "failed to read catalog file $file: $!";
    return &parseXMLCatalogue ($contents);
}

# Parse XML attribute sequence
sub parseXMLAttrs
{
    my ($string) = @_;
    my %attrs = ();
    $string =~ s/^\s+//;
    while ($string ne '')
    {
	if ($string =~ /^(\w+)='([^']*)'/) {
	    $attrs{$1} = $2; $string = $';
	 } elsif ($string =~ /^(\w+)="([^"]*)"/) {
	    $attrs{$1} = $2; $string = $';
	 } else {
	    die "unrecognised xml attributes: <$string>";
	 }
         $string =~ s/^\s+//;
    }

    return %attrs;
}

# Parse XML catalogue from a string.
sub parseXMLCatalogue
{
    my ($string) = @_;
    my $result = [];
    my @rows = split("\n", $string);
    while (defined ($_ = shift (@rows)))
    {
	if (m|<File\s(.*?)>|)
	{
	    my %attrs = &parseXMLAttrs ($1);
	    my ($guid, $frag) = ($attrs{ID}, { GUID => $attrs{ID}, TEXT => "$_\n" });
	    while (defined ($_ = shift (@rows)))
	    {
		$frag->{TEXT} .= "$_\n";
		chomp;

		if (m|<pfn\s(.*?)/>|) {
		    %attrs = &parseXMLAttrs ($1);
		    push (@{$frag->{PFN}},
			  { PFN => $attrs{'name'},
			    TYPE => $attrs{'filetype'} });
		} elsif (m|<lfn\s(.*?)/>|) {
		    %attrs = &parseXMLAttrs ($1);
		    push (@{$frag->{LFN}}, $attrs{'name'});
		} elsif (m|<metadata\s(.*?)/>|) {
		    %attrs = &parseXMLAttrs ($1);
		    $frag->{META}{$attrs{'att_name'}} = $attrs{'att_value'};
		    $frag->{GROUP} = $attrs{'att_value'}
		        if ($attrs{'att_name'} eq 'jobid');
		} elsif (m|</File>|) {
		    last;
		}
	    }

	    if (scalar @{$frag->{PFN}} != 1
		|| scalar @{$frag->{LFN}} != 1
		|| ! $guid)
	    {
		die "cannot understand catalog";
	    }
	    elsif (grep ($_->{GUID} eq $guid, @$result))
	    {
		die "catalogue has duplicate guid $guid";
	    }
	    else
	    {
		push (@$result, $frag);
	    }
	}
    }

    die "no guid mappings found in catalog" if ! @$result;
    return $result;
}

1;
