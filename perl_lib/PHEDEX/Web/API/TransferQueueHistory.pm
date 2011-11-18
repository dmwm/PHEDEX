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

  <link>
    <transferqueue>
    ...
  </link>
  ...

=head3 <link> elements

  from            name of the source node
  to              name of the destinatio node

=head3 <transferqueue> elements

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
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;
use PHEDEX::Web::Spooler;

sub duration { return 60 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }
#sub invoke { return transferqueuehistory(@_); }

my $map = {
    _KEY => 'FROM+TO',
    FROM => 'FROM',
    TO => 'TO',
    transferqueue => {
        _KEY => 'TIMEBIN',
        timebin => 'TIMEBIN',
        binwidth => 'BINWIDTH',
        ready_files => 'READY_FILES',
        ready_bytes => 'READY_BYTES',
        wait_files => 'WAIT_FILES',
        wait_bytes => 'WAIT_BYTES',
        pend_files => 'PEND_FILES',
        pend_bytes => 'PEND_BYTES',
        xfer_files => 'XFER_FILES',
        xfer_bytes => 'XFER_BYTES',
        confirm_files => 'CONFIRM_FILES',
        confirm_bytes => 'CONFIRM_BYTES'
    }
};

#sub transferqueuehistory
#{
#    my ($core, %h) = @_;
#
#    # convert parameter keys to upper case
#    foreach ( qw / from to starttime endtime binwidth ctime / )
#    {
#        $h{uc $_} = delete $h{$_} if $h{$_};
#    }
#
#    my $r = PHEDEX::Web::SQL::getTransferQueueHistory($core, %h);
#
#    return { link => PHEDEX::Core::Util::flat2tree($map, $r) };
#}

# spooling

my $sth;
our $limit = 1000;
my @keys = ('FROM', 'TO');
my %p;

sub spool
{
    my ($core, %h) = @_;

    if (!$sth)
    {
        eval
        {
            %p = &validate_params(\%h,
                    uc_keys => 1,
                    allow => [ qw / from to starttime endtime binwidth ctime / ],
                    spec =>
                    {
                        from => { using => 'node', multiple => 1 },
                        to   => { using => 'node', multiple => 1 },
                        starttime => { using => 'time' },
                        endtime => { using => 'time' },
                        binwidth => { using => 'pos_int' },
                        ctime => { using => 'yesno' },
                    }
            );
        };
        if ($@)
        {
            return PHEDEX::Web::Util::http_error(400,$@);
        }
        $p{'__spool__'} = 1;
        $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getTransferQueueHistory($core, %p), $limit, @keys);
    }
    my $r;

    $r = $sth->spool();
    if ($r)
    {
        return { link => PHEDEX::Core::Util::flat2tree($map, $r) };
    }
    else
    {
        $sth = undef;
        %p = ();
        return $r;
    }
}


1;
