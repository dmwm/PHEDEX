package PHEDEX::Web::API::LFN2PFN;
use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Core::Catalogue;

=pod
=head1 NAME

PHEDEX::Web::API::LFN2PFN

=cut

=pod

=head2 lfn2pfn

Translate LFNs to PFNs using the TFC published to TMDB.

=head3 options

 node          PhEDex node names, can be multiple (*), required
 lfn           Logical file name, can be multiple (*), required
 protocol      Transfer protocol, required
 destination   Destination node
 
 (*) See the rules of multi-value filters above

=head3 <mapping> attributes

 lfn          Logical file name
 pfn          Physical file name
 node         Node name
 protocol     Transfer protocol
 destination  Destination node

=cut

sub duration{ return 15 * 60; }
sub invoke { return lfn2pfn(@_); }
sub lfn2pfn
{
    my ($self,$core,%h) = @_;
    &checkRequired(\%h, 'node', 'lfn', 'protocol');

    # TODO:  cache nodemap and TFC
    my $nodemap = { reverse %{$core->getNodeMap()} }; # node map name => id

    my $catcache = {};
    my $mapping = [];

    foreach my $node (&PHEDEX::Core::SQL::arrayref_expand($h{node})) {
	my $node_id = $nodemap->{$node};
	if (!$node_id) {
	    die "unknown node '$node'\n";
	}

	my $cat = &dbStorageRules($core->{DBH}, $catcache, $node_id);
	if (!$cat) {
	    die "could not retrieve catalogue for node $h{node}\n";
	}

	my @args = ($cat, $h{protocol}, $h{destination}, 'pre');
	push @$mapping, 
	map { { node => $node, protocol => $h{protocol}, destination => $h{destination},
		lfn => $_, pfn => &applyStorageRules(@args, $_) } }
	&PHEDEX::Core::SQL::arrayref_expand($h{lfn});                 # from either an array of lfns or one
	    
    }
    return { mapping => $mapping };
}

1;
