package PHEDEX::Web::API::DeleteRequests;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::DeleteRequests - deletion requests

=head1 DESCRIPTION

Serves information about deletion requests, including the data
requested for deletion, the client who created the request, and the
clients who approved or disapproved the request.

=head2 Options

  request          request number
  node             node name
  create_since     return only requests created after this time
  limit            maximum number of records returned

  approval         approval state: approved, disapproved, pending or mixed
                   default is all
  requested_by *   human name of the requestor

   * requested_by only works with approval option
  ** without any input, the default "create_since" is set to 24 hours ago

=head2 Output

  <request>
    <requested_by>
      <comments>...</comments>
    </requested_by>
    <nodes>
      <node>
        <decided_by>
          <comments>...</comments>
        </decided_by>
      </node>
      ...
    </nodes>
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
  rm_subscription  whether the subscription was removed with this
                   deletion

=head3 <node> elements

No attributes, <nodes> exists only to contain <node> elements.

=head3 <node> attributes

  id               node id
  name             node name
  se               node SE name

=head3 <data> attributes

  files            total requested files
  bytes            total requested bytes

=head3 <usertext> element

Plain text strings of data the user requested, possibly including
wildcards.

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
  dn               certificate distinguished name
  username         person's username
  email            email address
  host             remote host
  agent            client useragent string
  id               person's ID

=head3 <decided_by> attributes

  decision         y for approved, n for disapproved
  time_decided     timestamp the decision was made
  name             person's name
  dn               certificate distinguished name
  username         person's username
  email            email address
  host             remote host
  agent            client useragent string
  id               person's ID

This element will not exist if no decision has been taken yet.

=head3 <comment> elements

Plain text comments made when the request was created or decided on.
This element will not exist if there were no comments.

=cut


use PHEDEX::Web::SQL;

sub duration { return 60 * 60; }
sub invoke { return xfer_request(@_); }

sub xfer_request
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / request limit node create_since approval requested_by / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    # if there is no argument, set default "since" to 24 hours ago
    if (scalar keys %h == 0)
    {
        $h{CREATE_SINCE} = time() - 3600*24;
    }

    $h{TYPE} = 'delete';
    if (exists $h{APPROVAL})
    {
        my $r1 = PHEDEX::Web::SQL::getRequestList($core, %h);
        my %request;
        foreach (@{$r1})
        {
            $request{$_->{ID}} = 1;
        }
        my @request = keys(%request);
        if (@request)
        {
            $h{REQUEST} = \@request;
        }
        else
        {
            return { request => [] };
        }
    }
    my $r = PHEDEX::Web::SQL::getRequestData($core, %h);
    return { request => $r };
}

1;