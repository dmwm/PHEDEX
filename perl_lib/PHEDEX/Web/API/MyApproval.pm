package PHEDEX::Web::API::MyApproval;
use warnings;
use strict;
use Data::Dumper;


=pod

=head1 NAME

PHEDEX::Web::API::MyApproval - show to a person all required/optional actions he/she needs/can performed on a request 

=head1 DESCRIPTION

create 

=head2 Options

  request_id             request id 
  person_id              person id

=head2 Output

 <request>
 </request>

=head3 <request> attributes

  id               request id
  action name      
  role 
  request type 
  state name
 
=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::SQLRequest;
use PHEDEX::Core::Util;
use PHEDEX::Web::Util;

sub duration { return 60 * 60; }
sub invoke { return myapproval(@_); }

sub myapproval 
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


    $r = PHEDEX::Web::SQLRequest::myapproval($core, %p);
            
    return { template => $r };
}

1;
