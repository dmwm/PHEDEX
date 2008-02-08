package UtilsCatalogue; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(pfnLookup lfnLookup storageRules applyStorageRules);
use XML::Parser;

# Cache of already parsed storage rules.  Keyed by rule type, then by
# file name, and stores as value the file time stamp and parsed result.
my %cache;

# Map a LFN to a PFN using a storage mapping catalogue.  The first
# argument is either a single scalar LFN, or a reference to an array
# of LFNs.  The second and third arguments are desired protocol and
# destination node making query ("direct", "local" meaning direct
# access from the system agent is running on.  The last argument is
# the location of the storage catalogue.
#
# If given a single LFN, returns a single PFN, or undef if the name
# cannot be mapped.  If given an array of LFNs, returns a hash of
# LFN => PFN mappings; the hash will have an entry for every LFN,
# but the value will be undef if no PFN could be constructed.
sub pfnLookup
{
    my ($input, $proto, $dest, $mapping) = @_;
    my @args = (&storageRules ($mapping, 'lfn-to-pfn'), $proto, $dest, 'pre');
    if (ref $input)
    {
	return { map { $_ => &applyStorageRules(@args, $_) } @$input };
    }
    else
    {
	return &applyStorageRules(@args, $input);
    }
}

# Map a PFN to a LFN using a storage mapping catalogue.  This is like
# pfnLookup, but simply works the other way around.
sub lfnLookup
{
    my ($input, $proto, $dest, $mapping) = @_;
    my @args = (&storageRules ($mapping, 'pfn-to-lfn'), $proto, $dest, 'post');
    if (ref $input)
    {
	return { map { $_ => &applyStorageRules(@args, $_) } @$input };
    }
    else
    {
	return &applyStorageRules(@args, $input);
    }
}

# Read in rules for storage mappings.  Returns a reference to a hash
# by protocol, each of which points to an array of rules of $kind in
# the order in which they appeared in the <storage-mapping>.
#
# The storage rules are expected to be of the form:
#   all::   <storage-mapping> rule+ </storage-mapping>
#   rule::  <lfn-to-pfn args> | <pfn-to-lfn args>
#   args::  protocol="..." [destination-match="..."] [chain="..."]
#           path-match="..." result="..."
#
# More than one rule may be specified; the first applicable one wins.
# The value for the "protocol" argument is required and is compared
# literally to the protocol given by the client.  The "destination-
# match" argument is, if given, used as a perl regular expression to
# match the client's destination argument.  If the "chain" argument
# is present, it designates another protocol whose rules are applied
# to the file name on input (lfn-to-pfn) or ouput (pfn-to-lfn) of
# the current rule.
# 
# If the protocol and destination match, the file name is matched
# against the perl regular expression "path-match".   If matched,
# the name is transformed according to "result", following the
# conventions of the perl s/// operator.  Once the path has been
# matched rule processing ends.
#
# Example:
#   <storage-mapping>
#     <lfn-to-pfn protocol="direct"
#       path-match="/+(.*)" result="/castor/cern.ch/cms/$1"/>
#     <lfn-to-pfn protocol="srm" chain="direct"
#       path-match="(.*)" result="srm://srm.cern.ch/srm/managerv1?SFN=$1"/>
#
#     <pfn-to-lfn protocol="direct"
#       path-match="/+castor/cern\.ch/cms/(.*)" result="/$1"/>
#     <pfn-to-lfn protocol="srm" chain="direct"
#       path-match=".*\?SFN=(.*)" result="$1"/>
#   </storage-mapping>
#
# This would map LFN=/foo PROTO=srm DEST=(any) to
#   srm://srm.cern.ch/srm/managerv1?SFN=/castor/cern.ch/cms/foo.
sub storageRules
{
    my ($file, $kind) = @_;

    # Check if we have a valid cached result
    if (exists $cache{$kind}{$file})
    {
	my $modtime = (stat($file))[9];
	return $cache{$kind}{$file}{RULES}
	    if $cache{$kind}{$file}{MODTIME} == $modtime;
    }

    # Parse the catalogue and remove top-level white space
    my $tree = (new XML::Parser (Style => "Tree"))->parsefile ($file);
    splice (@$tree, 0, 2) while ($$tree[0] eq "0" && $$tree[1] =~ /^\s*$/s);
    splice (@$tree, -2) while ($$tree[scalar @$tree- 2] eq "0"
				&& $$tree[scalar @$tree- 1] =~ /^\s*$/s);

    # Verify we understand the storage catalogue structure
    die "$file: expected one top-level element\n" if scalar @$tree != 2;
    die "$file: expected storage-mapping element\n" if $$tree[0] ne 'storage-mapping';

    # Collect the rules we wanted
    my ($attrs, @rules) = @{$$tree[1]};
    my $result = {};
    while (@rules)
    {
	my ($element, $value) = splice(@rules, 0, 2);
	next if $element ne $kind;
	# $$value[0]{'path-match'} = do { my $z = $$value[0]{'path-match'}; qr/$z/ };
	# $$value[0]{'result'} = do { my $z = $$value[0]{'result'}; eval "sub { \$_[0] =~ s!\$_[1]!$z! }" };
	push (@{$$result{$$value[0]{protocol}}}, $$value[0]);
    }

    # Cache the result
    $cache{$kind}{$file} = { MODTIME => (stat($file))[9], RULES => $result };

    # Return to the caller
    return $result;
}

# Apply storage mapping rules to a file name.  See "storageRules" for details.
sub applyStorageRules
{
    my ($rules, $proto, $dest, $chain, $givenname) = @_;
    foreach my $rule (@{$$rules{$proto}})
    {
	my $name = $givenname;

	next if (defined $$rule{'destination-match'}
		 && $dest !~ m!$$rule{'destination-match'}!);

	if (exists $$rule{'chain'} && $chain eq 'pre') {
	    $name = &applyStorageRules($rules, $$rule{'chain'}, $dest, $chain, $name);
	}

	if ($name =~ m!$$rule{'path-match'}!)
	{
	    if (ref $$rule{'result'} eq 'CODE')
	    {
		&{$$rule{'result'}} ($name, $$rule{'path-match'});
	    }
	    else
	    {
		eval "\$name =~ s!\$\$rule{'path-match'}!$$rule{'result'}!";
	    }
	    $name = &applyStorageRules($rules, $$rule{'chain'}, $dest, $chain, $name)
		if (exists $$rule{'chain'} && $chain eq 'post');
	    return $name;
	}
	
    }

    return undef;
}

print STDERR "WARNING:  use of Common/UtilsCatalogue.pm is depreciated.  Update your code to use the PHEDEX perl library!\n";
1;
