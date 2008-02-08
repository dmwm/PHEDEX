package UtilsCache; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(mergeCatalogueToCache readAttributeCache outputAttributeCache);
use Data::Dumper;
use UtilsCommand;

# Merge information from a catalogue to an attribute cache
sub mergeCatalogueToCache
{
    my ($attrs, $catalogue) = @_;
    foreach my $entry (values %$catalogue)
    {
	my $guid = $entry->{GUID};
	my $pfn = $entry->{PFN}[0];
	my $lfn = $entry->{LFN}[0];
	my $meta = $entry->{META};

	my $old = (grep ($_->{GUID} eq $guid, @$attrs))[0];
	push(@$attrs, $old = {}) if ! $old;

	$old->{GUID} = $guid;
	$old->{PFN} = $pfn;
	$old->{LFN} = $lfn;
	$old->{META} = $meta;
    }
}

# Read file attribute cache.
sub readAttributeCache
{
    my ($file) = @_;
    my $content = &input($file);
    die "cannot read attribute cache $file: $!" if ! defined $content;
    my $cache = do { no strict "vars"; eval $content; };
    die "corrupted attribute cache $file: $@" if $@;
    die "corrupted attribute cache $file: no data" if ! defined $cache;
    die "corrupted attribute cache $file: unexpected data"
        if (ref($cache) ne 'ARRAY' || grep(ref($_) ne 'HASH', @$cache));
    return $cache;
}

# Write out a file attribute cache.
sub outputAttributeCache
{
    my ($file, $attrs) = @_;
    return &output ($file, Dumper ($attrs));
}

print STDERR "WARNING:  use of Common/UtilsCache.pm is depreciated.  Update your code to use the PHEDEX perl library!\n";
1;
