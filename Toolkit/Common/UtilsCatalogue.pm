package UtilsCatalogue; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(guidToPFN guidToLFN pfnToGUID);
use UtilsLogging;

# Map a GUID to a PFN using a catalogue.  Arguments are either
# a triplet (GUID, CATALOGUE-CONTACT, HOST-KEY) where GUID can
# be either a single GUID or a reference to an array of GUIDs.
# The HOST-KEY is a pattern that is matched against the PFNs
# to pick the one specific to the desired host.  Returns a
# PFN for single GUID and a hash of GUID => PFN mappings for
# an array of GUIDs; the hash will have a value for each GUID,
# undef if there was no PFNs for it in the catalogue.
sub guidToPFN
{
    my ($guid, $catalogue, $hostkey) = @_;
    my $home = $0; $home =~ s|/[^/]+$||;

    # FIXME: remove message suppression when pool has learnt to print
    # diagnostic output somewhere else other than stdout...

    # Query at most 50 at a time to keep command line short enough.
    my %data = ();
    my @items = ref $guid ? @$guid : $guid;
    while (@items)
    {
	my $n = $#items > 50 ? 50 : $#items;
	my @slice = @items[$#items - $n .. $#items];
	delete @items[$#items - $n .. $#items];

        open (CAT, "POOL_OUTMSG_LEVEL=100 $home/FClistGuidPFN -u '$catalogue' -g @slice |")
	    or do { &alert ("cannot run FClistGuidPFN: $!"); return undef; };
        while (<CAT>)
        {
	    chomp;
	    my ($resguid, $respfn) = /(\S+)/g;
	    $data{$resguid} = $respfn if $respfn =~ /$hostkey/;
        }
        close (CAT);
    }

    return ref $guid ? { map { $_ => $data{$_} } @$guid } : $data{$guid};
}

# Map a GUID to a LFN using a catalogue.  Like guidToPFN but
# returns LFNs instead of PFNs.  Doesn't take a host key as
# LFNs are not host-specific.
sub guidToLFN
{
	my ($guid, $catalogue) = @_;

    # FIXME: remove message suppression when pool has learnt to print
    # diagnostic output somewhere else other than stdout...

    # There's no way to do batches.  Do one at a time.
    my %data = ();
    my @items = ref $guid ? @$guid : $guid;
    foreach my $g (@items)
    {
        open (CAT, "POOL_OUTMSG_LEVEL=100 FClistLFN -u '$catalogue' -q \"guid='$g'\" |")
	    or do { &alert ("cannot run FClistPFN: $!"); return undef; };
    	<CAT>; chomp; $data{$g} = $_;
        close (CAT);
    }

    return ref $guid ? { map { $_ => $data{$_} } @$guid } : $data{$guid};
}

# Map a PFN to a GUID using a catalogue.  Like guidToPFN but
# works the other way around.  Doesn't take a host key.
sub pfnToGUID
{
    my ($pfn, $catalogue) = @_;
    my $home = $0; $home =~ s|/[^/]+$||;

    # FIXME: remove message suppression when pool has learnt to print
    # diagnostic output somewhere else other than stdout...

    # Query at most 50 at a time to keep command line short enough.
    my %data = ();
    my @items = ref $pfn ? @$pfn : $pfn;
    while (@items)
    {
	my $n = $#items > 50 ? 50 : $#items;
	my @slice = @items[$#items - $n .. $#items];
	delete @items[$#items - $n .. $#items];

        open (CAT, "POOL_OUTMSG_LEVEL=100 $home/FClistGuidPFN -u '$catalogue' -p @slice |")
	    or do { &alert ("cannot run FClistGuidPFN: $!"); return undef; };
        while (<CAT>)
        {
	    chomp;
	    my ($resguid, $respfn) = /(\S+)/g;
	    $data{$respfn} = $resguid;
        }
        close (CAT);
    }

    return ref $pfn ? { map { $_ => $data{$_} } @$pfn } : $data{$pfn};
}

1;
