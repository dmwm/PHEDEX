package PHEDEX::Web::API::BlockLatency;
use warnings;
use strict;
use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;

=pod

=head1 NAME

PHEDEX::Web::API::BlockLatency - all about block latency

=head1 DESCRIPTION

Return latency statistics for blocks currently in transfer

=head2 Options

  id                    block id
  block                 block name, could be multiple, could have wildcard
  dataset               dataset name, could be multiple, could have wildcard
  to_node               destination node, could be multiple, could have wildcard
  priority              priority, could be multiple
  custodial             y or n, default either
  subscribe_since       subscribed since this time, defaults to 24h ago if neither block/dataset nor to_node are set
  subscribe_before      subscribed before this time, defaults to 24h after subscribe_since if neither block/dataset nor to_node are set
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
  latest_replica        time when a file was most recently replicated
  last_replica          time when last file was replicated
  last_suspend          time the block was last observed suspended
  partial_suspend_time  seconds the block was suspended since the creation of the latest replica
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
            latest_replica => 'LATEST_REPLICA',
            last_replica => 'LAST_REPLICA',
            last_suspend => 'LAST_SUSPEND',
            partial_suspend_time => 'PARTIAL_SUSPEND_TIME',
            total_suspend_time => 'TOTAL_SUSPEND_TIME',
            latency => 'LATENCY'
        }
    }
};

sub duration{ return 60 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }

#sub invoke { return blockLatency(@_); }
#sub blockLatency
#{
#    my ($core,%h) = @_;
#
#    # take care of time
#    foreach ( qw / subscribe_since update_since / )
#    {
#        if ($h{$_})
#        {
#            $h{$_} = PHEDEX::Core::Timing::str2time($h{$_});
#            die PHEDEX::Web::Util::http_error(400,"invalid $_ value") if not defined $h{$_};
#        }
#    }
#
#    # convert parameter keys to upper case
#
#    foreach ( qw / id block dataset to_node priority custodial subscribe_since update_since latency_greater_than latency_less_than ever_suspended / )
#    {
#        $h{uc $_} = delete $h{$_} if $h{$_};
#    }
#
#    # if there is no block/dataset argument, set default "since" to 24 hours ago
#    if ((not $h{BLOCK}) && (not $h{DATASET}) && (not $h{TO_NODE}) && (not $h{SUBSCRIBE_SINCE}))
#    {
#	$h{SUBSCRIBE_SINCE} = time() - 3600*24;;
#    }
#
#    return { block => PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getBlockLatency($core,%h)) };
#}

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
	
	# if there is no block/dataset argument, set default "since" to 24 hours ago
	if ((not $p{BLOCK}) && (not $p{DATASET}) && (not $p{TO_NODE}) && (not $p{SUBSCRIBE_SINCE}))
	{
	    $p{SUBSCRIBE_SINCE} = time() - 3600*24;;
	}
	
	# set default "before" to 24h after "since" if block/dataset is not set
        if ((not $p{SUBSCRIBE_BEFORE}) && (not $p{DATASET}) && (not $p{BLOCK}) && (not $p{TO_NODE}))
        {
	    $p{SUBSCRIBE_BEFORE} = $p{SUBSCRIBE_SINCE} + 3600*24;
	}

	$p{'__spool__'} = 1;
	
    }
    
    $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getBlockLatency($core,%p), $limit, @keys) if !$sth;
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
