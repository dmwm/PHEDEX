package PHEDEX::Web::API::PFN2LFN;
use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::SQL;
use PHEDEX::Web::SQL;

=pod

=head1 NAME

PHEDEX::Web::API::PFN2LFN - PFN to LFN conversion

=head1 DESCRIPTION

Translate PFNs to LFNs using the TFC published to TMDB.

=head2 Options

 node          PhEDex node names, can be multiple (*), required
 pfn           Physical file name, can be multiple, required
 protocol      Transfer protocol, required
 destination   Destination node
 custodial     y or n, whether or not the dest is custodial.  default is n.
 
 (*) See the rules of multi-value filters in the Core module

=head2 Output

  <mapping/>
  ...

=head3 <mapping> attributes

 lfn          Logical file name
 pfn          Physical file name
 space_token  space token
 node         Node name
 protocol     Transfer protocol
 destination  Destination node
 custodial    y or n, whether the dest is custodial

=cut

sub duration{ return 15 * 60; }
# _pfn2lfn to be consistent with _lfn2pfn 
sub invoke { return _pfn2lfn(@_); }
sub _pfn2lfn
{
    my ($core,%h) = @_;
    my %p;
    eval
    {
        %p = &validate_params(\%h,
                allow => [ qw ( node pfn protocol destination custodial ) ],
                required => [ qw ( node pfn protocol )],
                spec =>
                {
                    node => { using => 'node', multiple => 1 },
                    pfn => { using => 'pfn', multiple => 1 },
                    protocol => { using => 'text', multiple => 1 },
                    destination => { using => 'node', multiple => 1 },
                    custodial => { using => 'yesno', multiple => 1 },
                }
        );
    };
    if ($@)
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }
    
    # TODO:  cache nodemap and TFC
    my $nodes = &PHEDEX::Web::SQL::getNodes($core, NODE => $p{node});

    unless (@$nodes) {
	die PHEDEX::Web::Util::http_error(400,"no nodes found for '", join(', ', &PHEDEX::Core::SQL::arrayref_expand($p{node})), "'");
    }

    my $catcache = {};
    my $mapping = [];

    foreach my $node (@$nodes) {
	my $cat = &dbStorageRules($core->{DBH}, $catcache, $node->{ID}, 'pfn-to-lfn');
	if (!$cat) {
	    die "could not retrieve catalogue for node $node->{NAME}\n";
	}

	my @args = ($cat, $p{protocol}, $p{destination}, 'pre');
	foreach my $pfn ( &PHEDEX::Core::SQL::arrayref_expand($p{pfn}) ) {
	    my ($spt, $lfn) = &applyStorageRules(@args, $pfn, $p{custodial});
	    push @$mapping, { node => $node->{NAME},
			      protocol => $p{protocol},
			      destination => $p{destination},
			      custodial => $p{custodial},
			      lfn => $lfn,
			      pfn => $pfn,
			      space_token => $spt };
	}
    }
    return { mapping => $mapping };
}

1;
