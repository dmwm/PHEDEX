package PHEDEX::Web::API::TransferRequests;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferRequests - transfer requests

=head1 DESCRIPTION

Serves transfer request information, including the data requested, the
requesting client, the approving clients, and the request options.

=head2 Options

  request          request number
  node             name of the destination node
  group            name of the group
  limit            maximal number of records returned
  create_since     created after this time

  * without any input, the default "create_since" is set to 24 hours ago

=head2 Output

  <request>
    <requested_by>
      <comments>...</comments>
    </requested_by>
    <destinations>
      <node>
        <decided_by>
          <comments>...</comments>
        </decided_by>
      </node>
      ...
    </destinations>
    <move_sources>
      <node>
        <decided_by>
          <comments>...</comments>
        </decided_by>
      </node>
      ...
    </move_sources>
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
  ...

=head3 <request> attributes

  id               request number
  group            group name
  priority         transfer priority
  custodial        is custodial?
  static           is static?
  move             is move?

=head3 <destinations> elements

No attributes, exists only to contain <node> elements representing the
target of the transfer.

=head3 <move_sources> elements

No attributes, exists only to contain <node> elements representing 
subscribed sources of a move request.  This element will not exist if 
the request is not for a move, or if there were no subscribed sources.

=head3 <node> attributes

  id               node id
  name             node name
  se               node SE name

=head3 <data> attributes

  files            total requested files
  bytes            total requested bytes

=head3 <usertext> element

No attributes, the contents of this element are the actual text
strings of data the user requested, possibly including wildcards.

=head3 <dbs> attributes

  name             dbs name
  id               dbs id

=head3 <dataset> attributes

  name             dataset name
  id               dataset id
  files            number of files
  bytes            number of bytes

=head3 <block> attributes

  name             block name
  id               block id
  files            number of files
  bytes            number of bytes

=head3 <requested_by> attributes

  name             person's name
  dn               person's DN
  username         person's username
  email            email address
  host             remote host
  agent            client useragent string
  id               person's ID

=head3 <decided_by> attributes

  decision         y for approved, n for disapproved
  time_decided     timestamp the decision was made
  name             person's name
  dn               person's DN
  username         person's username
  email            email address
  host             remote host
  agent            client useragent string
  id               person's ID

This element will not exist if no decision has been taken yet.

=head3 <comment> elements

No attributes, the text value gives the comments made when the request
was created or decided on.  This element will not exist if there were
no comments.

=cut


use PHEDEX::Web::SQL;

sub duration { return 60 * 60; }
sub invoke { return xfer_request(@_); }

sub xfer_request
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / request limit group node create_since / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    # if there is no input argument, set default "since" to 24 hours ago
    if (scalar keys %h == 0)
    {
        $h{CREATE_SINCE} = time() - 3600*24;
    }

    $h{TYPE} = 'xfer';
    my $r = PHEDEX::Web::SQL::getRequestData($core, %h);
    return { request => $r };
}

1;
