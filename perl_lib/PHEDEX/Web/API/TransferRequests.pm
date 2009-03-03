package PHEDEX::Web::API::TransferRequests;
#use warning;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferRequests -- get information regarding transfer requests

=head2 transferrequest

Return transfer request information in the following structure:

  <request>
    <requested_by/>
    <destinations>
      <node><approved_by/></node>
      ...
    </destinations>
    <sources>
      <node><approved_by/></node>
      ...
    </sources>
    <data>
        <usertext>
        ...
        </usertext>
        <dbs>
          <dataset/> ...
          <block/> ...
        </dbs>
    </data>
  </request> 

=head3 options

required inputs:  none
optional inputs: (as filters) req_num, dest_node, group

 req_num          request number
 dest_node        name of the destination node
 group            name of the group
 limit            maximal number of records returned
 since            created after this time

=head3 output

  <request>
    <requested_by/>
    <destinations>
      <node><approved_by/></node>
      ...
    </destinations>
    <sources>
      <node><approved_by/></node>
      ...
    </sources>
    <data>
        <usertext>
        ...
        </usertext>
        <dbs>
          <dataset/> ...
          <block/> ...
        </dbs>
    </data>
  </request> 

=head3 request attributes

 req_num          request number
 group            group name
 priority         transfer priority
 custodial        is custodial?
 static           is static?
 move             is move?
 <request_by>     person who requested
 comments         comments
 type             request type, always 'xfer' here
 request_bytes    total requested bytes

=head3 node attributes

 id               node id
 name             node name
 se               node SE name
 decision         is decision made
 time_decided     time when the decision was made
 <approved_by>    person by whom transfer through this node was approved
 comment          comment

=head3 usertext elements

the actual text strings of data the user requested 

=head3 dbs attributes

 name             dbs name
 id               dbs id

=head3 dataset attributes

 name             dataset name
 id               dataset id
 files            number of files
 bytes            number of bytes

=head3 block attributes

 name             block name
 id               block id
 files            number of files
 bytes            number of bytes

=head3 <requested_by>/<approved_by> attributes

 name             person's name
 dn               person's DN
 username         person's username
 email            email address
 host             remote host
 agent            agent used

=cut


use PHEDEX::Web::SQL;

sub duration { return 60 * 60; }
sub invoke { return xfer_request(@_); }

sub xfer_request
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / req_num limit group dest_node since / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    $h{TYPE} = 'xfer';
    my $r = PHEDEX::Web::SQL::getRequestData($core, %h);
    return { request => $r };
}

1;
