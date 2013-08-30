package PHEDEX::Web::API::TransferQueueStats;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferQueueStats - current transfer queue

=head1 DESCRIPTION

Serves transfer current state details for links currently in use.

=head2 Options

 required inputs:   none
 optional inputs:   from, to

 from               name of the from (source) node, could be multiple
 to                 name of the to (destination) node, could be multiple

=head2 Output

  <link>
    <transfer_queue/>
    ...
  </link>
  ...

=head3 <link> elements

 from               name of the from (source) node
 to                 name of the to (destination) node
 from_id            id of the from node
 to_id              id of the to node

=head3 <transfer_queue> elements

 priority           transfer priority
 files              number of files in transfer
 bytes              number of bytes in transfer
 time_update        time when it was updated
 state              "assigned", "exported", "transferring", or "transferred"

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;

sub duration { return 60 * 60; }
sub invoke { return agent(@_); }

our $spec = {
    from => { using => 'node', multiple => 1 },
    to   => { using => 'node', multiple => 1 },
};

sub agent
{
    my ($core, %h) = @_;
    my %p;

    eval
    {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [qw(from to)],
                $spec,
         );
    };
    if ($@)
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }

    my $r = PHEDEX::Web::SQL::getTransferQueueStats($core, %p);
    return { link => $r };
}

1;
