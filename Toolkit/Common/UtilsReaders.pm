package UtilsReaders; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(readChecksumData readXMLCatalogue parseXMLCatalogue parseXMLAttrs);
use XML::Parser;

# Read job checksum data: lines of "CHECKSUM SIZE FILE".
sub readChecksumData
{
    my ($file) = @_;
    open (IN, "< $file") or die "cannot read checksum file $file: $!\n";
    my @result = ();
    while(<IN>)
    {
	chomp;

	# Skip empty lines
	next if /^$/;

	# Process matching lines (<checksum> <size> <filename>)
	if (/^(-?\d+) (-?\d+) (\S+)$/)
	{
	    push(@result, [ $1, $2, $3 ]);
	}
	else
	{
	    # Complain about bad lines
	    close (IN);
	    die "unrecognised checksum line: $file:$.\n";
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
    open (IN, "< $file") or die "cannot read catalog file $file: $!\n";
    my $contents = join("", <IN>);
    close (IN) or die "failed to read catalog file $file: $!\n";
    return &parseXMLCatalogue ($contents);
}

# Parse XML catalogue from a string.
sub parseXMLCatalogue
{
    my ($string) = @_;
    
    # Remove any "diff" noise in the catalogue
    $string =~ s/^\d+a$//mg;
    $string =~ s/^\.$//mg;

    # If it has no catalogue wrapper, add one
    my $doctype = "<!DOCTYPE POOLFILECATALOG SYSTEM \"InMemory\">";
    $string = "$doctype\n<POOLFILECATALOG>\n$string\n</POOLFILECATALOG>\n"
        if $string =~ /^\s*<File/s;

    # Parse the catalogue and remove top-level white space
    my $parsed = (new XML::Parser (Style => "Tree"))->parse ($string);
    while ($parsed->[0] eq "0" && $parsed->[1] =~ /^\s*$/s)
    {
	shift (@$parsed);
	shift (@$parsed);
    }
    while ($parsed->[scalar @$parsed - 2] eq "0"
	   && $parsed->[scalar @$parsed - 1] =~ /^\s*$/s)
    {
	pop (@$parsed);
	pop (@$parsed);
    }

    # Now reconstruct our own thing from it
    die "unexpected catalogue structure, expected single result\n"
        if scalar @$parsed != 2;
    die "unexpected catalogue structure, expected top POOLFILECATALOG\n"
        if $parsed->[0] ne 'POOLFILECATALOG';

    my $result = [];
    my ($attrs, @contents) = @{$parsed->[1]};
    while (@contents)
    {
	my ($element, $value) = splice (@contents, 0, 2);

	# Verify we've got what we like: white-space, META or File
	next if ($element eq "0" && $value =~ /^\s*$/s);
	next if ($element eq "META");
	die "unexpected catalogue element $element\n" if $element ne 'File';

	# Get file information
	$attrs = shift (@$value);
	die "no guid for catalogue file\n" if ! $attrs->{ID};
	my $f = { GUID => $attrs->{ID}, PFN => [], LFN => [] };
	push (@$result, $f);
	while (@$value)
	{
	    my ($el, $val) = splice (@$value, 0, 2);
	    next if ($el eq "0" && $val =~ /^\s*$/s);
	    if ($el eq "physical")
	    {
		shift (@$val);
		while (@$val)
		{
		    my ($e, $v) = splice (@$val, 0, 2);
		    next if ($e eq "0" && $v =~ /^\s*$/s);
		    die "unexpected catalogue element $e\n" if $e ne 'pfn';
		    push (@{$f->{PFN}}, { PFN => $v->[0]{'name'}, TYPE => $v->[0]{'filetype'} });
		}
	    }
	    elsif ($el eq "logical")
	    {
		shift (@$val);
		while (@$val)
		{
		    my ($e, $v) = splice (@$val, 0, 2);
		    next if ($e eq "0" && $v =~ /^\s*$/s);
		    die "unexpected catalogue element $e\n" if $e ne 'lfn';
		    push (@{$f->{LFN}}, $v->[0]{'name'});
		}
	    }
	    elsif ($el eq "metadata")
	    {
		die "metadata element must be empty\n" if scalar @$val > 1;
		$f->{META}{$val->[0]{'att_name'}} = $val->[0]{'att_value'};
	    }
	}
    }

    return $result;
}

1;
