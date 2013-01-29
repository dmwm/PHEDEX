package PHEDEX::Web::API::BlockArrive;
use warnings;
use strict;
use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;

=pod

=head1 NAME

PHEDEX::Web::API::BlockArrive - all about block estimated time of arrival

=head1 DESCRIPTION

Return estimated time of arrival for blocks currently subscribed for transfer
If the ETA cannot be calculated, or the block will never arrive, a reason for
the missing estimate is provided.

=head2 Options

  id                    block id
  block                 block name, could be multiple, could have wildcard
  dataset               dataset name, could be multiple, could have wildcard
  to_node               destination node, could be multiple, could have wildcard
  priority              priority, could be multiple
  update_since          updated since this time
  basis                 technique used for the ETA calculation, or reason it's missing - see below
  arrive_before         only show blocks that are expected to arrive before this time
  arrive_after          only show blocks that are expected to arrive after this time

 (*) See the rules of multi-value filters in the Core module

=head2 Output

  <block>
     <destination/>
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
  files                 number of files in block at the time of the estimate
  bytes                 block size at the time of the estimate
  priority              transfer priority 
  basis                 technique used for the ETA calculation, or reason it's missing - see below
  time_update           time when the ETA was updated
  time_span             historical vision used in estimate
  pend_bytes            queue size in bytes used in estimate
  xfer_rate             transfer rate used in estimate
  time_arrive           ETA for the block

=head3 Basis values

Negative values are for blocks which are not expected to complete without
external intervention.
Non-negative values are for blocks which are expected to complete.

 -6 : at least one file in the block has no source replica remaining
 -5 : for at least one file in the block, there is no path from source to destination
 -4 : subscription was automatically suspended by router for too many failures
 -3 : there is no active download link to the destination
 -2 : subscription was manually suspended
 -1 : block is still open
  0 : all files in the block are currently routed. FileRouter estimate is used to calculate ETA
  1 : the block is not yet routed because the destination queue is full
  2 : at least one file in the block is currently not routed, because it recently failed to transfer, and is waiting for rerouting

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
	files => 'AFILES',
	bytes => 'ABYTES',
	priority => 'PRIORITY',
	time_update => 'ATIME_UPDATE',
	basis => 'BASIS',
	time_span => 'TIME_SPAN',
	pend_bytes => 'PEND_BYTES',
	xfer_rate => 'XFER_RATE',
	time_arrive => 'TIME_ARRIVE'     
        
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
				  allow => [qw(id block dataset to_node priority update_since arrive_before arrive_after )],
				  spec => {
				      id => { using => 'pos_int', multiple => 1 },
				      block => { using => 'block_*', multiple => 1 },
				      dataset => { using => 'dataset', multiple => 1 },
				      to_node => { using => 'node', multiple => 1 },
				      priority => { using => 'priority', multiple =>1 },
				      update_since => { using => 'time' },
				      basis => { using => 'int' },
				      arrive_before => { using => 'time' },
				      arrive_after => { using => 'time' },
				  }
				  );
        };
	
	if ($@)
	{
	    return PHEDEX::Web::Util::http_error(400,$@);
	}
	
	# take care of time
	foreach ( qw / UPDATE_SINCE ARRIVE_BEFORE ARRIVE_AFTER / )
	{
	    if ($p{$_})
	    {
		$p{$_} = PHEDEX::Core::Timing::str2time($p{$_});
		die PHEDEX::Web::Util::http_error(400,"invalid $_ value") if not defined $p{$_};
	    }
	}
	
	$p{'__spool__'} = 1;
	
    }
    
    $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getBlockArrive($core,%p), $limit, @keys) if !$sth;
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
