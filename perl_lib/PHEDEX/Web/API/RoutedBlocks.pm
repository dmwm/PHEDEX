package PHEDEX::Web::API::RoutedBlocks;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::RoutedBlocks -- show Currently routed blocks, as well as failed routing attempts (invalid routes)

=head1 DESCRIPTION

Currently routed blocks, as well as failed routing attempts (invalid routes) 

=head2 Options

 required inputs:  none
 optional inputs:  (as filters) from, to, block, valid

  from             name of the source node, could be multiple
  to               name of the destination node, could be multiple
  block            block name, allows wildcard, could be multiple
  dataset          dataset name, allows wildcard, could be multiple
  valid            y or n, filter for valid routes. default is either

=head2 Output

  <route>
    <block>
    ...
  </route>
  ... 

=head3 <route> attributes: 

  from             source node of the route
  from_id          from node id
  from_se          from node storage element
  to               destination node of the route
  to_id            to_node id
  to_se            to_node storage element
  priority         priority of the route
  valid            y/n, whether the route is valid

=head3 <block> attributes: 

  name             block name
  id               block id
  files            number of files in this block
  bytes            number of bytes in this block
  routed_files     number of files routed from this block
  routed_bytes     number of bytes routed from this block
  xfer_attempts    transfer attempts
  avg_attempts     average transfer attempts per routed file
  time_request     time the routing request was made

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;

sub duration { return 60 * 60; }
sub invoke { return routedblocks(@_); }

my $map = {
    _KEY => 'FROM+TO',
    from => 'FROM',
    from_id => 'FROM_ID',
    from_se => 'FROM_SE',
    to => 'TO',
    to_id => 'TO_ID',
    to_se => 'TO_SE',
    priority => 'PRIORITY',
    valid => 'VALID',
    block => {
        _KEY => 'BLOCK_ID',
        id => 'BLOCK_ID',
        name => 'BLOCK',
        files => 'FILES',
        bytes => 'BYTES',
        route_files => 'ROUTE_FILES',
        route_bytes => 'ROUTE_BYTES',
        xfer_attempts => 'XFER_ATTEMPTS',
        time_request => 'TIME_REQUEST',
        avg_attempts => 'AVG_ATTEMPTS'
    }
};
        
sub routedblocks
{
    my ($core, %h) = @_;
    my %p;
    eval
    {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [ qw/ from to valid block dataset / ],
                spec =>
                {
                    from    => { using => 'node', multiple => 1 },
                    to      => { using => 'node', multiple => 1 },
                    block   => { using => 'block_*', multiple => 1 },
                    dataset => { using => 'dataset', multiple => 1 },
                    valid   => { using => 'yesno' }
                }
        );
    };
    if ($@)
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }

    my $r = PHEDEX::Web::SQL::getRoutedBlocks($core, %p);
    return { route => &PHEDEX::Core::Util::flat2tree($map, $r) };
}

1;
