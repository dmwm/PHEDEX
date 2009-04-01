package PHEDEX::Web::API::TransferQueueBlocks;

use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransQueueBlocks

=head2 DESCRIPTION

Return blocks in the transfer queue, along with their state.

=head3 options

 required inputs: none
 optional inputs: (as filters) from, to, state, priority, block

  from             from node name, could be multiple
  to               to node name, could be multiple
  block            a block name, could be multiple
  priority         one of the following:
                     high, normal, low
  state            one of the following:
                     transferred, transfering, exported

=head3 output

 <link>
   <transfer_queue>
     <block/>
     ....
   </transfer_queue>
   ....
 </link>

=head3 <link> elements:
  from             name of the source node
  from_id          id of the source node
  from_se          se of the source node
  to               name of the destination node
  to_id            id of the to node
  to_se            se of the to node

=head3 <transfer_queue> elements:

  priority         priority of this queue
  state            one of the following:
                     transferred, transfering, exported

=head3 <block> elements:

  name             block name
  id               block id
  files            number of files in this block
  bytes            number of bytes in this block

=cut

use PHEDEX::Web::SQL;

sub duration { return 60 * 60; }
sub invoke { return transferqueueblocks(@_); }

sub transferqueueblocks
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / from to state priority block / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $links = PHEDEX::Web::SQL::getTransferQueue($core, %h);
    return { link => [ values %$links ] };
}

1;
