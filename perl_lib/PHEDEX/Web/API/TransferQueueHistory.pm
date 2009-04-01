package PHEDEX::Web::API::TransferQueueHistory;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferQueueHistory - history of transfer queues

=head1 DESCRIPTION

Serves historical information about transfer queues.

=head2 Options

 required inputs: none (default to be the last hour)
 optional inputs: from, to, timebin, timewidth

  from            name of the source node, could be multiple
  to              name of the destination node, could be multiple
  starttime       start time
  endtime         end time
  binwidth        width of each timebin in seconds
  (ctime)         set output of time in YYYY-MM-DD hh:mm:ss format
                  otherwise, output of time is in UNIX time format

  default values:
  endtime = now
  binwidth = 3600
  starttime = endtime - binwidth

=head3 format of time

  starttime and endtime could in one of the following format
  [1] <UNIX time>            (integer)
  [2] "YYYY-MM-DD"           (assuming 00:00:00)
  [3] "YYYY-MM-DD hh:mm:ss"

=head2 Output

  <link/>
  ...

=head3 <link> elements

  from            name of the source node
  to              name of the destinatio node
  timebin         the end point of each timebin, aligned with binwidth
  binwidth        width of each timebin (from the input)
  pend_files      number of files in any state
  pend_bytes      number of bytes in any state
  wait_files      number of files wating export
  wait_bytes      number of bytes waiting export
  ready_files     number of files exported waiting for transfer
  ready_bytes     number of bytes exported waiting for transfer
  xfer_files      number of files in transfer
  xfer_bytes      number of bytes in transfer
  confirm_files   number of files which have valid route over this link
  confirm_bytes   number of bytes which have valid route over this link

=head2 Relation with time

  starttime <= timebin < endtime
  number of bins = (endtime - starttime)/binwidth

=cut 

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use Data::Dumper;

sub duration { return 60 * 60; }
sub invoke { return transferqueuehistory(@_); }

sub transferqueuehistory
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / from to starttime endtime binwidth ctime / )
    {
        $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getTransferQueueHistory($core, %h);

    return { link => $r };
}

1;
