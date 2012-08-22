package PHEDEX::Web::API::NodeUsageHistory;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::NodeUsageHistory -- history of space usage at a node

=head1 DESCRIPTION

Show how space is being used at a node

=head2 Options

  required inputs:   none
  optional inputs:   node, starttime, endtime, timewidth

  node               name of the node, could be multiple
  starttime          start time
  endtime            end time
  binwidth           width of each timebin in seconds

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

  <node>
    <usage/>
    ...
  </node>
  ...

=head3 <node> elements

  name               node name
  id                 node id
  se                 storage element

=head3 <usage> elements

  timebin            the end point of each timebin, aligned with binwidth
                     * when binwidth == endtime - starttime, timebin = starttime
  binwidth           width of each timebin (from the input)
  cust_node_files    number of files in custodial storage
  cust_node_bytes    number of bytes in custodial storage
  cust_dest_files    number of files subscribed to custodial storage
  cust_dest_bytes    number of bytes subscribed to custodial storage
  noncust_node_files number of files in non-custodial storage
  noncust_node_bytes number of bytes in non-custodial storage
  noncust_dest_files number of files subscribed to non-custodial storage
  noncust_dest_bytes number of bytes subscribed to non-custodial storage
  src_node_files     number of files generated at this node
  src_node_bytes     number of bytes generated at this node
  request_files      number of files requested
  request_bytes      number of bytes requested
  idle_files         number of files that are idle
  idle_bytes         number of bytes that are idle

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use PHEDEX::Web::Spooler;
use PHEDEX::Web::Util;

# mapping format for the output
my $map = {
    _KEY => 'NODE_NAME',
    name => 'NODE_NAME',
    id => 'NODE_ID',
    se => 'SE',
    usage => {
        _KEY => 'TIMEBIN',
        timebin => 'TIMEBIN',
        binwidth => 'BINWIDTH',
        cust_node_files => 'CUST_NODE_FILES',
        cust_node_bytes => 'CUST_NODE_BYTES',
        cust_dest_files => 'CUST_DEST_FILES',
        cust_dest_bytes => 'CUST_DEST_BYTES',
        noncust_node_files => 'NONCUST_NODE_FILES',
        noncust_node_bytes => 'NONCUST_NODE_BYTES',
        noncust_dest_files => 'NONCUST_DEST_FILES',
        noncust_dest_bytes => 'NONCUST_DEST_BYTES',
        src_node_files => 'SRC_NODE_FILES',
        src_node_bytes => 'SRC_NODE_BYTES',
        request_files => 'REQUEST_FILES',
        request_bytes => 'REQUEST_BYTES',
        idle_files => 'IDLE_FILES',
        idle_bytes => 'IDLE_BYTES'
    }
};

sub duration { return 60 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }
#sub invoke { return nodeusagehistory(@_); }

#sub nodeusagehistory
#{
#    my ($core, %h) = @_;
#
#    # convert parameter keys to upper case
#    foreach ( qw / node starttime endtime binwidth ctime / )
#    {
#      $h{uc $_} = delete $h{$_} if $h{$_};
#    }
#
#    my $r = PHEDEX::Web::SQL::getNodeUsageHistory($core, %h);
#    return { node => &PHEDEX::Core::Util::flat2tree($map, $r) };
#}

my $sth;
our $limit = 1000;
my @keys = ('NODE_NAME');
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
                    allow => [ qw / node starttime endtime binwidth / ],
                    spec =>
                    {
                        node => { using => 'node', multiple => 1 },
                        starttime => { using => 'time' },
                        endtime => { using => 'time' },
                        binwidth => { using => 'pos_int' },
                    }
            );
        };
        if ($@)
        {
            return PHEDEX::Web::Util::http_error(400,$@);
        }
        $p{'__spool__'} = 1;
        $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getNodeUsageHistory($core, %p), $limit, @keys);
    }

    my $r = $sth->spool();

    if ($r)
    {
        return { node => &PHEDEX::Core::Util::flat2tree($map, $r) };
    }
    else
    {
        $sth = undef;
        %p = ();
        return $r;
    }
}

1;
