package PHEDEX::Web::API::TransferQueueBlocks;
#use warning;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransQueueBlocks - return information regarding the Agents

=head2 transferqueueblocks

Return transfer queue block information in the following structure:

 <link>
   <transfer_queue>
     <block/>
     ....
   </transfer_queue>
   ....
 </link>

=head3 options

 required inputs: none
 optional inputs: (as filters) from, to, state, priority

  from             from node name, could be multiple
  to               to node name, could be multiple
  priority         one of the following: (not working yet)
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

=head3 options

 required inputs: none
 optional inputs: (as filters) from, to, state, priority

=head3 <link> elements:
  from             name of the source node
  from_id          id of the source node
  to               name of the destination node
  to_id            id of the to node

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
    foreach ( qw / from to state priority / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getTransferQueueBlocks($core, %h);
    return { link => $r };
}

1;
