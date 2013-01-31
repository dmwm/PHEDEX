package PHEDEX::Web::API::BlockLatencyLog;
use warnings;
use strict;
use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;

=pod

=head1 NAME

PHEDEX::Web::API::BlockLatencyLog - all about historical block latency

=head1 DESCRIPTION

Return latency statistics for completed block transfers

=head2 Options

  id                    block id
  block                 block name, could be multiple, could have wildcard
  dataset               dataset name, could be multiple, could have wildcard
  to_node               destination node, could be multiple, could have wildcard
  priority              priority, could be multiple
  custodial             y or n, default either
  subscribe_since       subscribed since this time, defaults to 24h ago if block/dataset is not set
  subscribe_before      subscribed before this time, defaults to 24h after subscribe_since if block/dataset is not set
  update_since          updated since this time
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
  first_request         time when the first file was routed
  first_replica         time when the first replica was done
  percent25_replica     time when 25% of the files were replicated
  percent50_replica     time when 50% of the files were replicated
  percent75_replica     time when 75% of the files were replicated
  percent95_replica     time when 95% of the files were replicated
  last_replica          time when last file was replicated
  primary_from_node     name of the node from which most of the files were transferred
  primary_from_id       id of the node from which most of the files were transferred
  primary_from_files    number of files transferred from primary_from_node
  total_xfer_attempts   total number of transfer attempts for all files in the block
  total_suspend_time    seconds the block was suspended since the start of the transfer
  latency               latency

=cut

use PHEDEX::Core::Util;
use PHEDEX::Core::Timing;
use PHEDEX::Web::Spooler;

my $map = {
    _KEY => 'LROWID',
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
	    primary_from_node => 'PRIMARY_FROM_NODE',
	    primary_from_id => 'PRIMARY_FROM_ID',
	    primary_from_files => 'PRIMARY_FROM_FILES',
	    total_xfer_attempts => 'TOTAL_XFER_ATTEMPTS',
            total_suspend_time => 'TOTAL_SUSPEND_TIME',
            latency => 'LATENCY'
        }
    }
};

sub duration{ return 60 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }

my $sth;
my $limit = 1000;
my @keys = ('ID');
my %p;

sub spool
{
    my ($core,%h) = @_;

    if (!$sth)

    {
        eval {
            %p = &validate_params(\%h,
                                  uc_keys => 1,
                                  allow => [qw(id block dataset to_node priority custodial subscribe_since subscribe_before update_since latency_greater_than latency_less_than ever_suspended )],
                                  spec => {
                                      id => { using => 'pos_int', multiple => 1 },
                                      block => { using => 'block_*', multiple => 1 },
                                      dataset => { using => 'dataset', multiple => 1 },
                                      to_node => { using => 'node', multiple => 1 },
                                      priority => { using => 'priority', multiple =>1 },
                                      custodial => { using => 'yesno' },
				      subscribe_since => { using => 'time' },
				      subscribe_before => { using => 'time' },
				      update_since => { using => 'time' },
                                      latency_greater_than => { using => 'float' },
                                      latency_less_than => { using => 'float' },
                                      ever_suspended => { using => 'yesno' }
                                  }
                                  );
        };

        if ($@)
        {
            return PHEDEX::Web::Util::http_error(400,$@);
        }
	
	# take care of time
	foreach ( qw / SUBSCRIBE_SINCE SUBSCRIBE_BEFORE UPDATE_SINCE / )
	{
	    if ($p{$_})
	    {
		$p{$_} = PHEDEX::Core::Timing::str2time($p{$_});
		die PHEDEX::Web::Util::http_error(400,"invalid $_ value") if not defined $p{$_};
	    }
	}
	
	# set default "since" to 24 hours ago if block/dataset is not set
	if ((not $p{SUBSCRIBE_SINCE}) && (not $p{DATASET}) && (not $p{BLOCK}))
	{
	    $p{SUBSCRIBE_SINCE} = time() - 3600*24;
	}

	# set default "before" to 24h after "since" if block/dataset is not set
        if ((not $p{SUBSCRIBE_BEFORE}) && (not $p{DATASET}) && (not $p{BLOCK}))
        {
	    $p{SUBSCRIBE_BEFORE} = $p{SUBSCRIBE_SINCE} + 3600*24;
	}
    
	$p{'__spool__'} = 1;

    }

    $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getBlockLatencyLog($core,%p), $limit, @keys) if !$sth;
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
