package UtilsCatalogue; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(guidToPFN guidToLFN pfnToGUID);
use UtilsTiming;
use UtilsLogging;

# Map a GUID to a PFN using a catalogue.  First argument is either
# a single GUID, or a reference to an array of GUIDs.  The second
# and third arguments are the desired protocol and node making the
# query ("direct", "local" for access at the agent computer), and
# the rest of the arguments are the site-specific command to execute.
#
# Returns a PFN for single GUID and a hash of GUID => PFN mappings
# for an array of GUIDs; the hash will have a value for each GUID,
# undef if there was no PFNs for it in the catalogue.
sub guidToPFN
{
    my ($guid, $proto, $node, @cmd) = @_;

    # Query limited number of items to keep command line short enough.
    my $timing = []; &timeStart($timing);
    my @items = ref $guid ? @$guid : $guid;
    my %data = ();
    while (@items)
    {
	my @slice = splice (@items, 0, 500);
        open (CAT, "@cmd -g $proto $node @slice |")
	    or do { &alert ("failed to run @cmd: $!"); return undef; };
        while (<CAT>)
        {
	    chomp;
	    my ($g, $p) = /(\S+)/g;
	    $data{$g} = $p;
        }
        close (CAT);
    }

    return ref $guid ? { map { $_ => $data{$_} } @$guid } : $data{$guid};
}

# Map a PFN to a GUID using a catalogue.  Like guidToPFN but
# works the other way around.  Doesn't take a host key.
sub pfnToGUID
{
    my ($pfn, $proto, $node, @cmd) = @_;

    # Query limited number of items to keep command line short enough.
    my $timing = []; &timeStart($timing);
    my @items = ref $pfn ? @$pfn : $pfn;
    my %data = ();
    while (@items)
    {
	my @slice = splice (@items, 0, 500);
        open (CAT, "@cmd -p $proto $node @slice |")
	    or do { &alert ("failed to run @cmd: $!"); return undef; };
        while (<CAT>)
        {
	    chomp;
	    my ($g, $p) = /(\S+)/g;
	    $data{$p} = $g;
        }
        close (CAT);
    }

    return ref $pfn ? { map { $_ => $data{$_} } @$pfn } : $data{$pfn};
}

1;
