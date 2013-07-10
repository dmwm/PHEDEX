package PHEDEX::Web::API::viewApprovalPlan;
use warnings;
use strict;
use Data::Dumper;


=pod

=head1 NAME

PHEDEX::Web::API::viewApprovalPlan -  present the current state of the approval plan, especially the decisions

=head1 DESCRIPTION

create 

=head2 Options

  request_id             request id 

=head2 Output

 <request>
 </request>

=head3 <request> attributes

  id               request id
  request_type     request type, 'xfer' or 'delete'
  approval_type    approval type, one of 'all', 'any','single'

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::SQLRequest;
use PHEDEX::Core::Util;
use PHEDEX::Web::Util;

sub duration { return 60 * 60; }
sub invoke { return viewApprovalPlan(@_); }

sub viewApprovalPlan 
{
    my ($core, %h) = @_;
    my (%p,$r);
    eval
    {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [ qw / request_id / ],
                spec =>
                {
                   request_id => { using => 'pos_int', multiple => 1 },
                }
        );
    };
    if ( $@ )
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }


    $r = PHEDEX::Web::SQLRequest::viewApprovalPlan($core, %p);
            
    return { template => $r };
}

1;
