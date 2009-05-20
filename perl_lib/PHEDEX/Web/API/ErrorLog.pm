package PHEDEX::Web::API::ErrorLog;
#use warning;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::ErrorLog - transfer error logs

=head1 DESCRIPTION

Return detailed transfer error information, including logs of the
transfer and validation commands.

Note that PhEDEx only stores the last 100 errors per link, so more
errors may have occurred then indicated by this API call.

=head3 Options

 required inputs: at least one of the followings
 optional inputs: (as filters) from, to, block, lfn

  from             name of the source node, could be multiple
  to               name of the destination node, could be multiple
  block            block name
  lfn              logical file name

=head3 Output

  <link>
    <block>
      <file>
        <transfer_error>
           <transfer_log> ... </transfer_log>
           <detail_log> ... </detail_log>
           <validate_log> ... </detail_log>
        </transfer_error>
      </file>
    </block>
  </link>

=head3 <link> elements:

  from             name of the source node
  from_id          id of the source node
  to               name of the destination node
  to_id            id of the destination node
  from_se          se of the source node
  to_se            se of the destination node

=head3 <block> elements:

  name             block name
  id               block id

=head3 <file> elements:

  name             file name
  id               file id
  bytes            file length
  checksum         checksum

=head3 <transfer_error> elements:

  transfer_code    transfer code
  time_assign      time when it was assigned
  time_export      time when it was exported
  time_inxfer      time when it was pumped
  time_xfer        time when the transfer started
  time_done        time when it was done
  time_expire      expiration time
  from_pfn         physical file name at source
  to_pfn           physical file name at destination
  space_token      space token

=head3 <transfer_log/>, <detail_log/>, <validate_log/>

Full text of the transfer log, the detail log, and the validate log.

=cut


use PHEDEX::Web::SQL;

sub duration { return 60 * 60; }
sub invoke { return errorlog(@_); }

sub errorlog
{
    my ($core, %h) = @_;

    # need at least one of the input
    if (!$h{from}&&!$h{to}&&!$h{block}&&!$h{lfn})
    {
       die "need at least one of the input argument: from, to, block, lfn";
    }

    # convert parameter keys to upper case
    foreach ( qw / from to block lfn / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getErrorLog($core, %h);
    return { link => $r };
}

1;
