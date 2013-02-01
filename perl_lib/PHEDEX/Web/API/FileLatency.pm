package PHEDEX::Web::API::FileLatency;
use warnings;
use strict;
use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;

=pod

=head1 NAME

PHEDEX::Web::API::FileLatency - all about file-level latency for files currently in transfer

=head1 DESCRIPTION

Return file-level details on latency statistics for incomplete block transfers

=head2 Options

  required: lfn/block/dataset

  id                    block id
  block                 block name, could be multiple, could have wildcard
  dataset               dataset name, could be multiple, could have wildcard
  lfn                   logical file name, could be multiple, could have wildcard
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
        <blocklatency>
           <filelatency/>
           ...
        </blocklatency>
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

=head3 <blocklatency> attributes

  files                 number of files in block
  bytes                 block size
  priority              transfer priority
  is_custodial          is it custodial?
  time_subscription     time when the block was subscribed
  time_update           time when block latency status was updated
  block_create          time when the block was created
  block_close           time when the block was closed
  latest_replica        time when a file was most recently replicated
  last_replica          time when last file was replicated
  last_suspend          time the block was last observed suspended
  partial_suspend_time  seconds the block was suspended since the creation of the latest replica
  total_suspend_time    seconds the block was suspended since the start of the transfer
  latency               latency

=head3 <filelatency> attributes

  id                    file id, can be NULL for invalidated files
  lfn                   logical file name
  size                  file size
  time_create           time when the file was created
  time_update           time when file latency status was updated
  priority              task priority
  is_custodial          task custodiality
  time_request          timestamp of the first time the file was activated for transfer by FileRouter
  original_from_node_id node id of the source node for the first valid transfer path created by FileRouter
  original_from_node    source node for the first valid transfer path created by FileRouter
  from_node_id          node id of the source node for the successful transfer task (can differ from above in case of rerouting)
  from_node             source node for the successful transfer task (can differ from above in case of rerouting)
  time_route            timestamp of the first time that a valid transfer path was created by FileRouter
  time_assign           timestamp of the first time that a transfer task was created by FileIssue
  time_export           timestamp of the first time was exported for transfer (staged at source Buffer, or same as assigned time for T2s)
  attempts              number of transfer attempts
  time_first_attempt    timestamp of the first transfer attempt
  time_latest_attempt   timestamp of the most recent transfer attempt
  time_on_buffer        timestamp of the successful WAN transfer attempt (to Buffer for T1 nodes)
  time_at_destination   timestamp of arrival on destination node (same as before for T2 nodes, or migration time for T1s)

=cut

use PHEDEX::Core::Util;
use PHEDEX::Core::Timing;
use PHEDEX::Web::Spooler;

my $map = {
    _KEY => 'BLOCK_ID',
    id => 'BLOCK_ID',
    name => 'BLOCK',
    dataset => 'DATASET',
    files => 'FILES',
    bytes => 'BYTES',
    time_create => 'BLOCK_TIME_CREATE',
    time_update => 'BLOCK_TIME_UPDATE',
    destination => {
        _KEY => 'DESTINATION',
        name => 'DESTINATION',
        id => 'DESTINATION_ID',
        se => 'DESTINATION_SE',
	blocklatency => {
	    _KEY => "BTIME_SUBSCRIPTION+BIS_CUSTODIAL",
	    files => 'BFILES',
	    bytes => 'BBYTES',
	    priority => 'BPRIORITY',
	    is_custodial => 'BIS_CUSTODIAL',
	    time_subscription => 'BTIME_SUBSCRIPTION',
	    time_update => 'BTIME_UPDATE',
	    block_create => 'BLOCK_CREATE',
	    block_close => 'BLOCK_CLOSE',
	    latest_replica => 'LATEST_REPLICA',
	    last_replica => 'LAST_REPLICA',
	    last_suspend => 'LAST_SUSPEND',
	    partial_suspend_time => 'PARTIAL_SUSPEND_TIME',
	    total_suspend_time => 'TOTAL_SUSPEND_TIME',
	    latency => 'LATENCY',
	    filelatency => {
		_KEY => "FROWID",
		id => "FILE_ID",
		lfn => "LFN",
		size => "FILESIZE",
		time_create => 'FTIME_CREATE',
		time_update => 'FTIME_UPDATE',
		priority => 'FPRIORITY',
		is_custodial => 'FIS_CUSTODIAL',
		time_request => 'TIME_REQUEST',
		original_from_node_id => 'ORIGINAL_FROM_NODE_ID',
		original_from_node => 'ORIGINAL_FROM_NODE',
		from_node_id => 'FROM_NODE_ID',
		from_node => 'FROM_NODE',
		time_route => 'TIME_ROUTE',
		time_assign => 'TIME_ASSIGN',
		time_export => 'TIME_EXPORT',
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
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }

my $sth;
my $limit = 1000;
my @keys = ('BLOCK_ID');
my %p;

sub spool
{
    my ($core,%h) = @_;
    
    if (!$sth) 

    {
	eval {
            %p = &validate_params(\%h,
				    uc_keys => 1,
				    allow => [qw(id block dataset lfn to_node priority custodial subscribe_since subscribe_before update_since latency_greater_than latency_less_than ever_suspended )],
				    require_one_of => [ qw(block dataset lfn) ],
				    spec => {
				      id => { using => 'pos_int', multiple => 1 },
				      lfn => { using => 'lfn', multiple => 1 },
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
	
	$p{'__spool__'} = 1;
	
    }

    $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getFileLatency($core,%p), $limit, @keys) if !$sth;
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
