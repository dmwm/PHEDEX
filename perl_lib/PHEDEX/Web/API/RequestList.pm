package PHEDEX::Web::API::RequestList;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::RequestList - list of request according to search criteria

=head1 DESCRIPTION

Serve as a simple request search and cache-able catalog of requests to save within a client, which may then use the request ID to obtain further details using TransferRequests or DeletionRequests.

=head2 Options

  request *        request id
  type             request type, 'xfer' (default) or 'delete'
  approval         approval state, 'approved', 'disapproved', 'mixed', or 'pending'
  requested_by *   requestor's name
  node *           name of the destination node
                   (show requests in which this node is involved)
  decision         decision at the node, 'approved', 'disapproved' or 'pending'
  group *          user group
  create_since     created since this time
  create_until     created until this time
  decide_since     decided since this time
  decide_until     decided until this time
  dataset *        dataset is part of request, or a block from this dataset
  block *          block is part of request, or part of a dataset in request
  decided_by *     name of person who approved the request

  * could be multiple and/or with wildcard
 ** when both 'block' and 'dataset' are present, they form a logical disjunction (ie. or)

=head2 Output

 <request id= type= state= time_create= >
   <node id= se= name= decision= time_decide= />
 </request>

=head3 <request> attributes

  id               request id
  type             request type, 'xfer' or 'delete'
  approval         approval state, one of 'approved', 'disapproved', 'mixed', 'pending'
  requested_by     the human name of the person who made the request
  time_create      creation timestamp

=head3 <node> attributes

  id               node id
  name             node name
  se               node SE name
  decision         decision at the node, 'approved', 'disapproved' or 'pending'
  decided_by       the human name of the person who made
  time_decided     timestamp the decision was made

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use PHEDEX::Web::Util;

my $map = {
    _KEY => 'ID',
    id => 'ID',
    type => 'TYPE',
    requested_by => 'REQUESTED_BY',
    time_create => 'TIME_CREATE',
    node => {
        _KEY => 'NODE_ID',
        id => 'NODE_ID',
        se => 'SE_NAME',
        name => 'NODE_NAME',
        decision => 'DECISION',
        decided_by => 'DECIDED_BY',
        time_decided => 'TIME_DECIDED'
    }
};

sub duration { return 60 * 60; }
sub invoke { return request_list(@_); }

sub request_list
{
    my ($core, %h) = @_;
    my %p;
    eval
    {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [ qw / request group type approval requested_by node decision create_since create_until decide_since decide_until dataset block decided_by / ],
                spec =>
                {
                    request => { using => 'pos_int', multiple => 1 },
                    group => { using => 'text', multiple => 1 },
                    type => { using => 'request_type' },
                    approval => { using => 'approval_state', multiple => 1 },
                    requested_by => { using => 'text', multiple => 1 },
                    decided_by => { using => 'text', multiple => 1 },
                    node => { using => 'node', multiple => 1 },
                    decision => { using => 'approval_state', multiple => 1 },
                    create_since => { using => 'time' },
                    create_until => { using => 'time' },
                    decide_since => { using => 'time' },
                    decide_until => { using => 'time' },
                    dataset => { using => 'dataset', multiple => 1 },
                    block => { using => 'block_*', multiple => 1 },
                }
        );
    };
    if ( $@ )
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }

    my $r = PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getRequestList($core, %p));
    # take care of the approval
    foreach my $request (@{$r})
    {
        my $nodes = 0;
        my $yes = 0;
        my $no = 0;
        foreach (@{$request->{node}})
        {
            $yes += 1 if ($_->{decision} eq 'approved');
            $no += 1 if ($_->{decision} eq 'disapproved');
            $nodes += 1;
        }

        if (($yes+$no) < $nodes)
        {
            $request->{approval} = 'pending';
        }
        elsif ($yes == $nodes)
        {
            $request->{approval} = 'approved';
        }
        elsif ($no == $nodes)
        {
            $request->{approval} = 'disapproved';
        }
        else
        {
            $request->{approval} = 'mixed';
        }
    }
            
    return { request => $r };
}

1;
