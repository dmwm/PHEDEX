package PHEDEX::Web::API::RouterHistory;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::RouterHistory -- History of file routing statistics

=head1 DESCRIPTION

Show history of file routing statistics. 

=head2 Options

  required inputs: none (default to be the last hour)
  optional inputs: (as filters) from, to, timebin, binwidth

  from              name of the source node, could be multiple
  to                name of the destination node, could be multiple
  starttime         start time
  endtime           end time
  binwidth          width of each timebin in seconds
  (ctime)           set output of time in YYYY-MM-DD hh:mm:ss format
                    otherwise, output of time is in UNIX time format

  default values:
  endtime = now
  binwidth = 3600
  starttime = endtime - binwidth

  format of time

  starttime and endtime could in one of the following format
  [1] <UNIX time> (integer)
  [2] "YYYY-MM-DD" (assuming 00:00:00 UTC)
  [3] "YYYY-MM-DD hh:mm:ss" (UTC) 

=head2 Output

  <link>
    <route/>
    ...
  </link>
  ...

=head3 <link> elements

  from              name of the source node
  to                name of the destination node

=head3 <route> elements

  timebin           the end point of each timebin, aligned with binwidth
                    * when binwidth == endtime - starttime, timebin = starttime
  binwidth          width of each timebin (from the input)
  route_files       number of files which have valid route over this link
  route_bytes       number of bytes which have valid route over this link
  rate              rate used by the router in bytes per second
  latency           latency used by the router in seconds
  request_files     number of files actively requested for routing to destination
  request_bytes     number of bytes actively requested for routing to destination
  idle_files        number of files waiting for re-routing to destination
  idle_bytes        number of files waiting for re-routing to destination

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;

# mapping format for the output
my $map = {
    _KEY => 'FROM_NODE+TO_NODE',
    from => 'FROM_NODE',
    to => 'TO_NODE',
    route => {
        _KEY => 'TIMEBIN',
        timebin => 'TIMEBIN',
        binwidth => 'BINWIDTH',
        route_files => 'ROUTE_FILES',
        route_bytes => 'ROUTE_BYTES',
        rate => 'RATE',
        latency => 'LATENCY',
        request_files => 'REQUEST_FILES',
        request_bytes => 'REQUEST_BYTES',
        idle_files => 'IDLE_FILES',
        idle_bytes => 'IDLE_BYTES'
    }
};

sub duration { return 60 * 60; }
sub invoke { return routerhistory(@_); }

sub routerhistory
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / from to starttime endtime binwidth ctime / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getRouterHistory($core, %h);
    return { link => &PHEDEX::Core::Util::flat2tree($map, $r) };
}

1;
