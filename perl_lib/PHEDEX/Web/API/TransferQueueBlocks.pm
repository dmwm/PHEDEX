package PHEDEX::Web::API::TransferQueueBlocks;

use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferQueueBlocks - blocks currently queued for transfer

=head1 DESCRIPTION

Serves blocks in the transfer queue, along with their state.

=head2 Options

 required inputs: none
 optional inputs: (as filters) from, to, state, priority, block

  from             from node name, could be multiple
  to               to node name, could be multiple
  block            a block name, could be multiple
  dataset          dataset name, could be multiple
  priority         one of the following:
                     high, normal, low
  state            one of the following:
                     assigned, exported, transferring, done

=head2 Output

 <link>
   <transfer_queue>
     <block/>
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
  files            number of files in this block
  bytes            number of bytes in this block
  time_assign      minimum assignment time for a file in the block
  time_expire      minimum expiration time for a file in the block
  time_state       minimum time a file achieved its current state

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;

my $map = {
    _KEY => 'FROM_ID+TO_ID',
    from => 'FROM_NAME',
    from_id => 'FROM_ID',
    from_se => 'FROM_SE',
    to => 'TO_NAME',
    to_id => 'TO_ID',
    to_se => 'TO_SE',
    transfer_queue => {
        _KEY => 'STATE+PRIORITY',
        state => 'STATE',
        priority => 'PRIORITY',
        block => {
            _KEY => 'BLOCK_ID',
            name => 'BLOCK_NAME',
            id => 'BLOCK_ID',
            files => 'FILES',
            bytes => 'BYTES',
            time_state => 'TIME_STATE',
            time_assign => 'TIME_ASSIGN',
            time_expire => 'TIME_EXPIRE'
        }
    }
};

sub duration { return 60 * 60; }
sub invoke { return transferqueueblocks(@_); }

sub transferqueueblocks
{
    my ($core, %h) = @_;
    my %p;
    eval
    {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [ qw / from to state priority block dataset / ],
                spec =>
                {
                    from => { using => 'node', multiple => 1 },
                    to   => { using => 'node', multiple => 1 },
                    block => { using => 'block_*', multiple => 1 },
                    dataset => { using => 'dataset', multiple => 1 },
                    priority => { using => 'priority' },
                    state => { using => 'transfer_state' }
                }
        );
    };
    if ($@)
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }

    my $r = PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getTransferQueue($core, %p));
    return { link => $r };
}

1;
