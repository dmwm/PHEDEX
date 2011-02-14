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
  (ctime)            set output of time in YYYY-MM-DD hh:mm:ss format
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

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use PHEDEX::Web::Spooler;

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
        src_node_bytes => 'SRC_NODE_BYTES'
    }
};

sub duration { return 60 * 60; }
sub invoke { return nodeusagehistory(@_); }

sub nodeusagehistory
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / node starttime endtime binwidth ctime / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getNodeUsageHistory($core, %h);
    return { node => &PHEDEX::Core::Util::flat2tree($map, $r) };
}

my $sth;
my $limit = 1000;
my @keys = ('NODE_NAME');

sub spool
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / node starttime endtime binwidth ctime / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }
    $h{'__spool__'} = 1;

    $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getNodeUsageHistory($core, %h), $limit, @keys) if !$sth;
    
    my $r = $sth->spool();

    if ($r)
    {
        return { node => &PHEDEX::Core::Util::flat2tree($map, $r) };
    }
    else
    {
        $sth = undef;
        return $r;
    }
}

1;