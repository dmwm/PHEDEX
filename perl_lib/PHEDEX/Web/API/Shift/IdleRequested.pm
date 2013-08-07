package PHEDEX::Web::API::Shift::IdleRequested;
use PHEDEX::Core::DB;
use PHEDEX::Web::API::Shift::Requested;
use PHEDEX::Web::API::Shift::Idle;

use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Shift::IdleRequested - Idle vs. Requested data analysis for shift personnel.

=head1 DESCRIPTION

Serves information about current activity in PhEDEx. This module is
specifically tailored to suit the needs of people on shift who are checking
that data is moving properly.

The code implements a check if the large amounts of idle requests 
existed for that node. The check takes several things into account.

First, it gets the number of bytes idle and requested for each node for 
each of the last 12 hours, with timebins aligned on the hour. Then it 
checks the ratio of bytes idle to bytes requested in each timebin, and 
attempts to deduce if the idle data is too much comparing to the requested data.

If no data is requested in any timebin, the queue is declared to be OK, 
and no further analysis is performed.

If some data is requested, but it is less than a preset minimum amount, 
the queue is also declared to be OK. Currently, that minimum is set at 1 
TB. Again, no further analysis is performed.

Next, each bin is checked. The ratio of idle to requested data is 
calculated. If the ratio is larger than 50%, the queue is considered to be 
idle for that timebin. If the ratio is less than 0.2, the queue is 
considered to be OK for that timebin. If the ratio is between 0.2 and 0.5, the 
timebin is considered to be in a warning state. 

If four or more consecutive timebins are idle, the queue is declared to 
be idle. If four or more consecutive timebins are in a warning state, the 
entire queue is considered to be in a warning state. If three or more 
consecutive timebins are OK after the queue has been declared idle, the 
'idle' state is downgraded to a warning state, since the queue may have 
recently recovered.

N.B. Data for T1 sites, which have a Buffer and an MSS node, are aggregated under the name of the MSS node. 

This algorithm is probably far from perfect. Suggestions on how to improve 
it are welcomed!

=head2 Options

 required inputs: none
 optional inputs: (as filters) node

  full             show information about all nodes, not just those with a problem

=head2 Output

  <idlerequested>
    <nesteddata/>
  </idlerequested>
  ...

=head3 <idlerequested> attributes

  status             status-code (numeric). 0 => OK, 1 => possible problem, 2 => problem
  status_text        textual representation of the status ('OK', 'Warn', 'Error')
  reason             reason for the assigned status
  node               node-name
  max_idle_bytes  Max. number of bytes idle for transfer in the interval under examination
  max_request_bytes     Max. number of bytes requested for transfer in the interval under examination
  cur_request_bytes  Number of bytes currently requested for transfer
  cur_idle_bytes     Number of bytes currently idle for transfer

=head3 <nesteddata> attributes

  request_bytes    number of bytes requested for transfer in the current timebin
  idle_bytes       number of bytes idle for transfer in the current timebin
  ratio            ratio of idle/requested bytes
  timebin          Unix epoch time of start of current timebin

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
sub duration { return 3600 - time%3600 + 60; } # Just after the top of the hour
sub invoke { return _shift_idlerequested(@_); }

sub _shift_idlerequested
{
  my ($core, %h) = @_;
  my ($epochHours,$start,$end,$node,%params,$p,$q,$mindata);
  my ($h,$ratio,$nConsecFail,$nConsecOK,$nConsecWarn);
  my (%s,$bin,$unique,$e,$buffer,$i,$j,$k,$status_map);

  $status_map = {
		  0 => 'OK',
		  1 => 'Warning',
		  2 => 'Error',
		};

  $epochHours = int(time/3600);
  $start = ($epochHours-12) * 3600;
  $end   =  $epochHours     * 3600;
  $node  = 'T%';
  %params = ( ':starttime' => $start, ':endtime' => $end, ':node' => $node );

  map { $h{uc $_} = uc delete $h{$_} } keys %h;
  $p = PHEDEX::Web::API::Shift::Idle::getShiftIdle($core,\%params,\%h);
  $q = PHEDEX::Web::API::Shift::Requested::getShiftRequested($core,\%params,\%h);

  $mindata = $h{MINDATA} || 1024*1024*1024*1024;

  $unique = 0;
  foreach $node ( keys %{$q} )
  {
    foreach $bin ( keys %{$q->{$node}} )
    {
      $q->{$node}{$bin}{RATIO} = 0;
      $q->{$node}{$bin}{IDLE_BYTES} = $p->{$node}{$bin}{IDLE_BYTES} || 0;
      if ( $q->{$node}{$bin}{IDLE_BYTES} )
      {
        $q->{$node}{$bin}{RATIO} = $q->{$node}{$bin}{IDLE_BYTES} / $q->{$node}{$bin}{REQUEST_BYTES};
      }
    }
  }

  foreach $node ( keys %{$q} )
  {
    if ( ! $s{$node} )
    {
      $s{$node} = {
			 NODE			=> $node,
			 MAX_IDLE_BYTES		=> 0,
			 MAX_REQUEST_BYTES	=> 0,
			 CUR_IDLE_BYTES		=> 0,
			 CUR_REQUEST_BYTES	=> 0,
			 TIMEBINS		=> {},
			 STATUS			=> 0,
			 REASON			=> 'OK',
			 NESTEDDATA		=> [],
			 UNIQUEID		=> $unique++,
		       };
    }
    $s{$node}{TIMEBINS} = $q->{$node};
  }

  foreach $node ( keys %s )
  {
#   Declare a problem is there are four consecutive bins where data is
#   idle larger than 50% of that data is requested.
    $nConsecFail  = $nConsecOK = 0;
    foreach $bin ( sort { $a <=> $b } keys %{$s{$node}{TIMEBINS}} )
    {
      $e = $s{$node}{TIMEBINS}{$bin};
      $e->{TIMEBIN} += 0; # numify for JSON encoder
      if ( $s{$node}{MAX_IDLE_BYTES} < $e->{IDLE_BYTES} )
         { $s{$node}{MAX_IDLE_BYTES} = $e->{IDLE_BYTES}; }
      if ( $s{$node}{MAX_REQUEST_BYTES} < $e->{REQUEST_BYTES} )
         { $s{$node}{MAX_REQUEST_BYTES} = $e->{REQUEST_BYTES}; }

      $s{$node}{CUR_IDLE_BYTES}    = $e->{IDLE_BYTES};
      $s{$node}{CUR_REQUEST_BYTES} = $e->{REQUEST_BYTES};

      $ratio = $e->{RATIO};
      if ( ! $e->{REQUEST_BYTES} ) { $nConsecFail = 0; }
      if ( $e->{REQUEST_BYTES} )
      { $ratio = $e->{IDLE_BYTES} / $e->{REQUEST_BYTES}; }
      if ( defined($ratio) )
      {
        if ( $ratio >= 0.5 ) { $nConsecFail++; }
        else                { $nConsecFail=0; }
        if ( $ratio < 0.2 ) { $nConsecOK++; }
        else                              { $nConsecOK=0;  }
        if ( $ratio < 0.5 && $ratio >= 0.2 ) { $nConsecWarn++; }
        else              { $nConsecWarn=0;  }
      }
      if ( $nConsecWarn >= 4 )
      {
        $s{$node}{STATUS} = 1;
        $s{$node}{REASON} = 'Idle is >= 20% of Requested';
      }
      if ( $nConsecFail >= 4 )
      {
        $s{$node}{STATUS} = 2;
        $s{$node}{REASON} = 'Idle is >= 50% of Requested';
      }
      if ( $nConsecOK >= 3 && $s{$node}{STATUS} )
      {
        $s{$node}{STATUS} = 1;
        $s{$node}{REASON} = 'The queued may be idle';
      }
      delete $e->{NODE};
      if ( $e->{IDLE_BYTES} )
      {
        $e->{RATIO} = sprintf('%.2f',$e->{RATIO});
      } else {
        $e->{RATIO} = '-';
      }
      push @{$s{$node}{NESTEDDATA}},$e;
    }

    if ( $s{$node}{MAX_REQUEST_BYTES} < $mindata )
    {
      $s{$node}{STATUS} = 0;
      $s{$node}{REASON} = 'Very little data requested';
    }
    if ( !$s{$node}{MAX_REQUEST_BYTES} )
    {
      $s{$node}{STATUS} = 0;
      $s{$node}{REASON} = 'No data requested';
    }

#   Sanity check...
    if ( !defined $s{$node}{REASON} )
    {
      die "REASON not defined for $node. Have you changed the algorithm?";
    }
    $s{$node}{STATUS_TEXT} = $status_map->{$s{$node}{STATUS}};
    $s{$node}{STATUS} += 0; # numification :-(
    delete $s{$node}{TIMEBINS};
    delete $s{$node} if ( !$s{$node}{STATUS} && !$h{FULL} );
  }

  my @r = values %s;
  return { idlerequested => \@r };
}

1;
