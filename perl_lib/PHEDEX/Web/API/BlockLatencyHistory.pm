package PHEDEX::Web::API::BlockLatencyHistory;
use warnings;
use strict;
use PHEDEX::Web::SQL;

=pod

=head1 NAME

PHEDEX::Web::API::BlockLatencyHistory - all about historical block latency

=head1 DESCRIPTION

Evenrything we want to know about historical block latency

=head2 Options

  id                    block id
  block                 block name, could be multiple, could have wildcard
  to_node               destination node, could be multiple, could have wildcard
  priority              priority, could be nultiple
  custodial             y or n, default either
  subscribe_since       subscribed since this time
  update_since          updated since this time
  first_request_since   first requested since this time
  latency_greater_than  only show latency that is greater than this
  latency_less_than     only show latency that is less than this
  ever_suspended        y or n, default neither


 (*) See the rules of multi-value filters in the Core module

=head2 Output

  <block>
     <destination>
        <latency/>
        ...
     </destination>
     ...
  </block>

=head3 <block> attributes

  id                    block id
  name                  block name
  dataset               dataset name
  files                 number of files in block
  bytes                 block size
  time_create           creation time
  time_update           update time

=head3 <destination> attributes

  name                  node name
  id                    node id
  se                    se name
 
=head3 <latency> attributes

  files                 number of files in block
  bytes                 block size
  priority              transfer priority
  is_custodial          is it custodial?
  time_subscription     time when the block was subscribed
  time_update           time when status was updated
  block_create          time when the block was created
  block_close           time when the block was closed
  first_request         time when the first file is routed
  first_replica         time when the first replica is done
  percent25_replica     time when 25% of the files were replicated
  percent50_replica     time when 50% of the files were replicated
  percent75_replica     time when 75% of the files were replicated
  percent95_replica     time when 95% of the files were replicated
  last_replica          time when last file was replicated
  total_suspend_time    seconds the block was suspended since the start of the transfer
  latency               latency

=cut

use PHEDEX::Core::Util;
use PHEDEX::Core::Timing;
use PHEDEX::Web::Spooler;

my $map = {
    _KEY => 'ID',
    id => 'ID',
    name => 'NAME',
    dataset => 'DATASET',
    files => 'FILES',
    bytes => 'BYTES',
    time_create => 'TIME_CREATE',
    time_update => 'TIME_UPDATE',
    destination => {
        _KEY => 'DESTINATION',
        name => 'DESTINATION',
        id => 'DESTINATION_ID',
        se => 'DESTINATION_SE',
        latency => {
            _KEY => 'TIME_SUBSCRIPTION+IS_CUSTODIAL',
            files => 'LFILES',
            bytes => 'LBYTES',
            priority => 'PRIORITY',
            is_custodial => 'IS_CUSTODIAL',
            time_subscription => 'TIME_SUBSCRIPTION',
            time_update => 'LTIME_UPDATE',
            block_create => 'BLOCK_CREATE',
            block_close => 'BLOCK_CLOSE',
            first_request => 'FIRST_REQUEST',
            first_replica => 'FIRST_REPLICA',
            percent25_replica => 'PERCENT25_REPLICA',
            percent50_replica => 'PERCENT50_REPLICA',
            percent75_replica => 'PERCENT75_REPLICA',
            percent95_replica => 'PERCENT95_REPLICA',
            last_replica => 'LAST_REPLICA',
            total_suspend_time => 'TOTAL_SUSPEND_TIME',
            latency => 'LATENCY'
        }
    }
};

sub duration{ return 60 * 60; }
sub invoke { return blockLatencyHistory(@_); }
sub blockLatencyHistory
{
    my ($core,%h) = @_;

    # take care of time
    foreach ( qw / subscribe_since first_request_since update_since / )
    {
        if ($h{$_})
        {
            $h{$_} = PHEDEX::Core::Timing::str2time($h{$_});
            die PHEDEX::Web::Util::http_error(400,"invalid $_ value") if not defined $h{$_};
        }
    }

    # convert parameter keys to upper case

    foreach ( qw / id block to_node priority custodial subscribe_since first_request_since update_since latency_greater_than latency_less_than ever_suspended / )
    {
        $h{uc $_} = delete $h{$_} if $h{$_};
    }

    return { block => PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getBlockLatencyHistory($core,%h)) };
}

my $sth;
my $limit = 1000;
my @keys = ('ID');

sub spool
{
    my ($core,%h) = @_;

    # take care of time
    foreach ( qw / subscribe_since first_request_since update_since / )
    {
        if ($h{$_})
        {
            $h{$_} = PHEDEX::Core::Timing::str2time($h{$_});
            die PHEDEX::Web::Util::http_error(400,"invalid $_ value") if not defined $h{$_};
        }
    }

    # convert parameter keys to upper case

    foreach ( qw / id block to_node priority custodial subscribe_since first_request_since update_since latency_greater_than latency_less_than ever_suspended / )
    {
        $h{uc $_} = delete $h{$_} if $h{$_};
    }

    $h{'__spool__'} = 1;

    $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getBlockLatencyHistory($core,%h), $limit, @keys) if !$sth;
    my $r = $sth->spool();

    if ($r)
    {
        foreach (@{$r})
        {
            $_->{PRIORITY} = PHEDEX::Core::Util::priority($_->{PRIORITY});
        }
        return { block => PHEDEX::Core::Util::flat2tree($map, $r)};
    }
    else
    {
        $sth = undef;
        return $r;
    }
}


1;
