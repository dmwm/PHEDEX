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
  pend_files        number of files queued
  pend_bytes        number of bytes queued

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use PHEDEX::Web::Spooler;
use PHEDEX::Web::Util;

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
        idle_bytes => 'IDLE_BYTES',
        pend_files => 'PEND_FILES',
        pend_bytes => 'PEND_BYTES'
    }
};

sub duration { return 60 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }
#sub invoke { return routerhistory(@_); }

#sub routerhistory
#{
#    my ($core, %h) = @_;
#
#    # convert parameter keys to upper case
#    foreach ( qw / from to starttime endtime binwidth ctime / )
#    {
#      $h{uc $_} = delete $h{$_} if $h{$_};
#    }
#
#    my $r = PHEDEX::Web::SQL::getRouterHistory($core, %h);
#    return { link => &PHEDEX::Core::Util::flat2tree($map, $r) };
#}

# spooling

my $sth;
our $limit = 1000;
my @keys = ('FROM_NODE', 'TO_NODE');
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
                    allow => [ qw / from to starttime endtime binwidth / ],
                    spec =>
                    {
                        from   => { using => 'node', multiple => 1 },
                        to     => { using => 'node', multiple => 1 },
                        starttime => { using => 'time' },
                        endtime => { using => 'time' },
                        binwidth => { using => 'pos_int' }
                    }
            );
        };
        if ($@)
        {
            return PHEDEX::Web::Util::http_error(400,$@);
        }
        $p{'__spool__'} = 1;
        $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getRouterHistory($core, %p), $limit, @keys);
    }

    my $r;
    $r = $sth->spool();
    if ($r) 
    {
        return { link => &PHEDEX::Core::Util::flat2tree($map, $r) };
    }
    else
    {
        $sth = undef;
        %p = ();
        return $r;
    }
}

1;
