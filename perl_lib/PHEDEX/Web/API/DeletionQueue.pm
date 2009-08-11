package PHEDEX::Web::API::DeletionQueue;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::DeletionQueue -- show deletion info

=head1 DESCRIPTION

Show deletion information

=head2 Options

 required inputs: none
 optional inputs: (as filters) node, block, se, request_since, complete_since

  node             node name, could be multiple
  se               storage element name, could be multiple
  block            block name, allow wildcard
  id               block id, allow multiple
  request          request id, could be multiple
  request_since    since time requested
  complete_since   since time completed

=head2 Output

  <block>
    <deletion/>
    ...
  </block>
  ...

=head3 <blcok> elements

  name             block name
  id               block id
  files            number of files in block
  bytes            number of size in block

=head3 <deletion> elements

  node             node name
  se               storage element name
  node_id          node id
  request          request id
  time_request     time the request was made
  time_complete    time the deletion was completed

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;

sub duration { return 60 * 60; }
sub invoke { return deletionqueue(@_); }

my $map = {
    _KEY => 'BLOCK_ID',
    id => 'BLOCK_ID',
    name => 'BLOCK',
    files => 'FILES',
    bytes => 'BYTES',
    deletion => {
        _KEY => 'NODE+REQUEST',
        request => 'REQUEST',
        node => 'NODE',
        se => 'SE',
        id => 'NODE_ID',
        time_request => 'TIME_REQUEST',
        time_complete => 'TIME_COMPLETE'
    }
};


sub deletionqueue
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / node se block id request request_since complete_since / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getDeletionQueue($core, %h);
    return { block => &PHEDEX::Core::Util::flat2tree($map, $r) };
}

1;
