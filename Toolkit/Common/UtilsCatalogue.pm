package UtilsCatalogue; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(guidToPFN guidToLFN pfnToGUID);
use UtilsLogging;

# Map a GUID to a PFN using a catalogue
sub guidToPFN
{
    my ($guid, $catalogue, $host) = @_;

    # FIXME: remove message suppression when pool has learnt to print
    # diagnostic output somewhere else other than stdout...
    open (PFNS, "POOL_OUTMSG_LEVEL=100 FClistPFN -u '$catalogue' -q \"guid='$guid'\" |")
	or do { &alert ("cannot run FClistPFN: $!"); return undef; };
    my @pfns = grep (/$host/, map { chomp; $_ } <PFNS>);
    close (PFNS);
    return $pfns[0];
}

# Map a GUID to a LFN using a catalogue
sub guidToLFN
{
    my ($guid, $catalogue) = @_;

    # FIXME: remove message suppression when pool has learnt to print
    # diagnostic output somewhere else other than stdout...
    open (LFNS, "POOL_OUTMSG_LEVEL=100 FClistLFN -u '$catalogue' -q \"guid='$guid'\" |")
	or do { &alert ("cannot run FClistPFN: $!"); return undef; };
    my @lfns = map { chomp; $_ } <LFNS>;
    close (LFNS);
    return $lfns[0];
}

# Map a PFN to GUID using a catalogue
sub pfnToGUID
{
    my ($pfn, $catalogue, $host) = @_;

    # FIXME: remove message suppression when pool has learnt to print
    # diagnostic output somewhere else other than stdout...
    my $home = $0; $home =~ s|/[^/]+$||;
    open (GUIDS, "POOL_OUTMSG_LEVEL=100 $home/FClistGuidPFN -u '$catalogue' -p '$pfn' |")
	or do { &alert ("cannot run FClistGuidPFN: $!"); return undef; };
    my @guids = map { chomp; [ split (/\s+/, $_) ] } <GUIDS>;
    close (GUIDS);
    return $guids[0][0];
}

1;
