package PHEDEX::Web::API::Routings;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Routings -- show routing information

=head1 DESCRIPTION

Show routing information

=head2 Options

 required inputs: none
 optional inputs: (as filters) source, destination, block

  source           name of the source node, could be multiple
  destination      name of the destination node, could be multiple
  block            block name, could have wildcard

=head2 Output

  <block>
    <routing/>
    ...
  </block>
  ...

=head3 <blcok> elements

  name             block name
  id               block id
  files            number of files in block
  bytes            number of size in block

=head3 <routing> elements

  source           name of the source node
  destination      name of the destination node
  priority         priority, low, normal or high
  is_valid         is the link valid
  route_files      number of files in this routing
  route_bytes      number of bytes in this routing
  xfer_attempts    transfer attempts
  avg_attempts     average transfer attempts per file
  time_request     time the request was made

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;

sub duration { return 60 * 60; }
sub invoke { return routing(@_); }

my $map = {
    _KEY => 'BLOCK_ID',
    id => 'BLOCK_ID',
    name => 'BLOCK',
    files => 'FILES',
    bytes => 'BYTES',
    routing => {
        _KEY => 'SOURCE+DESTINATION',
        source => 'SOURCE',
        priority => 'PRIORITY',
        destination => 'DESTINATION',
        route_files => 'ROUTE_FILES',
        route_bytes => 'ROUTE_BYTES',
        xfer_attempts => 'XFER_ATTEMPTS',
        time_request => 'TIME_REQUEST',
        avg_attempts => 'AVG_ATTEMPTS'
    }
};
        
sub routing
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / source destination block / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getRoutingInfo($core, %h);
    return { block => &PHEDEX::Core::Util::flat2tree($map, $r) };
}

1;
