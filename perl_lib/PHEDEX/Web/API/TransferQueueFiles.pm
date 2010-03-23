package PHEDEX::Web::API::TransferQueueFiles;

use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransQueueFiles - files currently queued for transfer

=head1 DESCRIPTION

Serves files in the transfer queue, along with their state.

=head2 Options

 required inputs: none
 optional inputs: (as filters) from, to, state, priority, block

  from             from node name, could be multiple
  to               to node name, could be multiple
  block            a block name, could be multiple
  priority         one of the following:
                     high, normal, low
  state            one of the following:
                     transferred, transfering, exported, done

=head2 Output

 <link>
   <transfer_queue>
     <block>
       <file/>
       ...
     </block>
     ....
   </transfer_queue>
   ....
 </link>

=head3 <link> elements
  from             name of the source node
  from_id          id of the source node
  from_se          se of the source node
  to               name of the destination node
  to_id            id of the to node
  to_se            se of the to node

=head3 <transfer_queue> elements

  priority         priority of this queue
  state            one of the following:
                     transferred, transfering, exported

=head3 <block> elements

  name             block name
  id               block id
  time_assign      minimum assignment time for a file in the block
  time_expire      minimum expiration time for a file in the block
  time_state       minimum time a file achieved its current state

=head3 <file> elements

  name             files logical name
  id               file id
  checksum         checksums of the file
  bytes            file size
  is_custodial     is it custodial? 'y' or 'n'
  time_assign      time the transfer task was created
  time_expire      time the transfer task will expire
  time_state       time the task achieved its current state

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use Data::Dumper;

sub duration { return 60 * 60; }
sub invoke { 
    my ($core, %h) = @_;

    # convert parameter key to upper case
    foreach ( qw / from to state priority block / )
    {
	$h{uc $_} = delete $h{$_} if $h{$_};
    }
    
    my $links = PHEDEX::Web::SQL::getTransferQueue($core, %h, LEVEL => 'FILE');    
    return { link => [ values %$links ] };
}

1;
