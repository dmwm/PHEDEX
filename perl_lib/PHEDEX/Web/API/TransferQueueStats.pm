package PHEDEX::Web::API::TransferQueueStats;
# use warning;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferQueueStats - show transfer state details

=head2 queueStats

return transfer state details in the following structure

  <link>
     <transfer_queue/>
     ...
  </link>
  ...

=head3 options

 required inputs:   none
 optional inputs:   from, to

 from               name of the from (source) node, could be multiple
 to                 name of the to (destination) node, could be multiple
=head3 output:

  <link>
    <transfer_queue/>
    ...
  </link>
  ...

=head3 <link> elements:

 from               name of the from (source) node
 to                 name of the to (destination) node
 from_id            id of the from node
 to_id              id of the to node
 queue              queues associated with this link

=head3 <transfer_queue> elements:

 priority           transfer priority
 files              number of files in transfer
 bytes              number of bytes in transfer
 time_update        time when it was updated
 state              "assigned", "exported", "transferring", or "transferred"

=cut

use PHEDEX::Web::SQL;
use Data::Dumper;

sub duration { return 60 * 60; }
sub invoke { return agent(@_); }

sub agent
{
    my ($core, %h) = @_;

    # convert parameter key to upper case
    foreach ( qw / from to / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getTransferQueueStats($core, %h);
    return { link => $r };
}

1;
