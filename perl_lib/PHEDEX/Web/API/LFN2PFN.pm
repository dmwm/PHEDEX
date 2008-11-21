package PHEDEX::Web::API::LFN2PFN;
use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::SQL;
use PHEDEX::Web::SQL;

=pod

=head1 NAME

PHEDEX::Web::API::LFN2PFN - LFN to PFN translation 

=head2 lfn2pfn

Translate LFNs to PFNs using the TFC published to TMDB.

=head3 options

 node          PhEDex node names, can be multiple (*), required
 lfn           Logical file name, can be multiple (+), required
 protocol      Transfer protocol, required
 destination   Destination node
 custodial     y or n, whether or not the dest is custodial.  default is n.
 
 (*) See the rules of multi-value filters in the Core module
 (+) Do not need to be registered LFNs

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
    my ($core,%h) = @_;
    &checkRequired(\%h, 'node', 'lfn', 'protocol');
    $h{custodial} ||= 'n';

    # TODO:  cache nodemap and TFC
    my $nodes = &PHEDEX::Web::SQL::getNodes($core, node => $h{node});

    unless (@$nodes) {
	die "no nodes found for '", join(', ', &PHEDEX::Core::SQL::arrayref_expand($h{node})), "'\n";
    }

    my $catcache = {};
    my $mapping = [];

    foreach my $node (@$nodes) {
	my $cat = &dbStorageRules($core->{DBH}, $catcache, $node->{ID});
	if (!$cat) {
	    die "could not retrieve catalogue for node $node->{NAME}\n";
	}

	my @args = ($cat, $h{protocol}, $h{destination}, 'pre');
	foreach my $lfn ( &PHEDEX::Core::SQL::arrayref_expand($h{lfn}) ) {
	    my ($spt, $pfn) = &applyStorageRules(@args, $lfn, $h{custodial});
	    push @$mapping, { node => $node->{NAME},
			      protocol => $h{protocol},
			      destination => $h{destination},
			      custodial => $h{custodial},
			      lfn => $lfn,
			      pfn => $pfn,
			      'space-token' => $spt };
	}
    }
    return { mapping => $mapping };
}

1;
