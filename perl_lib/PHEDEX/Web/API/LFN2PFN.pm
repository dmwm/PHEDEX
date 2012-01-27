package PHEDEX::Web::API::LFN2PFN;
use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::SQL;
use PHEDEX::Web::SQL;

=pod

=head1 NAME

PHEDEX::Web::API::LFN2PFN - LFN to PFN conversion

=head1 DESCRIPTION

Translate LFNs to PFNs using the TFC published to TMDB.

=head2 Options

 node          PhEDex node names, can be multiple (*), required
 lfn           Logical file name, can be multiple (+), required
 protocol      Transfer protocol, required
 destination   Destination node
 custodial     y or n, whether or not the dest is custodial.  default is n.
 
 (*) See the rules of multi-value filters in the Core module
 (+) Do not need to be registered LFNs

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
# _lfn2pfn to avoid clash with PHEDEX::Core::Catalogue, which exports lfn2pfn
sub invoke { return _lfn2pfn(@_); }
sub _lfn2pfn
{
    my ($core,%h) = @_;
    my %p;
    eval
    {
        %p = &validate_params(\%h,
                allow => [ qw ( node lfn protocol destination custodial ) ],
                required => [ qw ( node lfn protocol )],
                spec =>
                {
                    node => { using => 'node', multiple => 1 },
                    lfn => { using => 'lfn', multiple => 1 },
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
	my $cat = &dbStorageRules($core->{DBH}, $catcache, $node->{ID});
	if (!$cat) {
	    die "could not retrieve catalogue for node $node->{NAME}\n";
	}

	my @args = ($cat, $p{protocol}, $p{destination}, 'pre');
	foreach my $lfn ( &PHEDEX::Core::SQL::arrayref_expand($p{lfn}) ) {
	    my ($spt, $pfn) = &applyStorageRules(@args, $lfn, $p{custodial});
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
