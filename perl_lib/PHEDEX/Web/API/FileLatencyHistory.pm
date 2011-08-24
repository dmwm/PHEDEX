package PHEDEX::Web::API::FileLatencyHistory;
use warnings;
use strict;
use PHEDEX::Web::SQL;

=pod

=head1 NAME

PHEDEX::Web::API::FileLatencyHistory - all about historical file latency

=head1 DESCRIPTION

Evenrything we want to know about historical file latency

=head2 Options

  required: block or lfn

  id                    block id
  block                 block name, could be multiple, could have wildcard
  lfn                   logical file name
  to_node               destination node, could be multiple, could have wildcard
  priority              priority, could be nultiple
  custodial             y or n, default either
  subscribe_since       subscribed since this time
  update_since          updated since this time


 (*) See the rules of multi-value filters in the Core module

=head2 Output

  <block>
    <file>
      <destination>
        <latency/>
         ...
      </destination>
      ...
    </file>
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

=head3 <file> attributes

  id                    file id
  lfn                   logical file name
  size                  file size
  time_create           time when the file was created
 
=head3 <latency> attributes

  priority              transfer priority
  is_custodial          is it custodial?
  time_subscription     time when the block was subscribed
  time_update           time when status was updated
  time_request          time when it was requested
  time_routed           time when it was routed
  time_assign           time when it was assigned
  time_export           time when it was exported
  attempts              number of attempts
  time_first_attempt    time when the first attempt took place
  time_last_attempt     time when the last attempt took place
  time_on_buffer        time spent in buffer
  time_at_destination   time when arriving destination

=cut

use PHEDEX::Core::Util;
use PHEDEX::Core::Timing;
use PHEDEX::Web::Spooler;

my $map = {
    _KEY => 'BLOCK_ID',
    id => 'BLOCK_ID',
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
        file => {
            _KEY => "FILE_ID",
            id => "FILE_ID",
            lfn => "LFN",
            size => "FILESIZE",
            latency => {
                _KEY => "TIME_SUBSCRIPTION+IS_CUSTODIAL",
                time_subscription => 'TIME_SUBSCRIPTION',
                time_update => 'TIME_UPDATE',
                priority => 'PRIORITY',
                is_custodial => 'IS_CUSTODIAL',
                time_requested => 'TIME_REQUEST',
                time_routed => 'TIME_ROUTE',
                time_assigned => 'TIME_ASSIGN',
                time_exported => 'TIME_EXPORT',
                attempts => 'ATTEMPTS',
                time_first_attempt => 'TIME_FIRST_ATTEMPT',
                time_latest_attempt => 'TIME_LATEST_ATTEMPT',
                time_on_buffer => 'TIME_ON_BUFFER',
                time_at_destination => 'TIME_AT_DESTINATION'
            }
        }
    }
};

sub duration{ return 60 * 60; }
sub invoke { return FileLatencyHistory(@_); }
sub FileLatencyHistory
{
    my ($core,%h) = @_;

    die "block or lfn is required" if (!$h{block} && !$h{lfn});

    # take care of time
    foreach ( qw / subscribe_since update_since / )
    {
        if ($h{$_})
        {
            $h{$_} = PHEDEX::Core::Timing::str2time($h{$_});
            die "invalid $_ value" if not defined $h{$_};
        }
    }

    # convert parameter keys to upper case

    foreach ( qw / id block lfn to_node priority custodial subscribe_since update_since / )
    {
        $h{uc $_} = delete $h{$_} if $h{$_};
    }

    return { block => PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getFileLatencyHistory($core,%h)) };
}

my $sth;
my $limit = 1000;
my @keys = ('ID');

sub spool2
{
    my ($core,%h) = @_;

    # take care of time
    foreach ( qw / subscribe_since first_request_since update_since / )
    {
        if ($h{$_})
        {
            $h{$_} = PHEDEX::Core::Timing::str2time($h{$_});
            die "invalid $_ value" if not defined $h{$_};
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
