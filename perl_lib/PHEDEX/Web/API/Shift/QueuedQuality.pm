package PHEDEX::Web::API::Shift::QueuedQuality;
use PHEDEX::Core::DB;
use PHEDEX::Web::API::Shift::Quality;
use PHEDEX::Web::API::Shift::Queued;

use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Shift::QueuedQuality - Queued vs. quality data analysis for shift personnel.

=head1 DESCRIPTION

Serves information about current activity in PhEDEx. This module is
specifically tailored to suit the needs of people on shift who are checking
that data is moving properly.

The code implements a check if queued data is failing or not attempted
for that node. 

It gets the number of bytes pending and queued for each node for 
each of the last 12 hours, with timebins aligned on the hour.
If data was queued in a given hour, and for four hours following that hour 
one of the following is true
 1) quality is below 50%; 2) no blocks appear, nothing was attempted;
Then the node is likely to have a problem, and put into error status.
If quality is below 80%, the node is put into warning status.
If quality is 0, it means the node is trying and failing permanently 
If quality is undef, it means the node is not trying at all

If four or more consecutive timebins are failed, the queue is declared to
be failed. If four or more consecutive timebins are in a warning state, the
entire queue is considered to be in a warning state. If three or more
consecutive timebins are OK after the queue has been declared failed, the
'ERROR' state is downgraded to a warning state, since the queue may have
recently recovered.


N.B. Data for T1 sites, only Buffer node is taken into account. 


=head2 Options

 required inputs: none
 optional inputs: (as filters) node

  full             show information about all nodes, not just those with a problem

=head2 Output

  <queuedquality>
    <nesteddata/>
  </queuedquality>
  ...

=head3 <queuedquality> attributes

  status             status-code (numeric). 0 => OK, 1 => possible problem, 2 => problem
  status_text        textual representation of the status ('OK', 'Warn', 'Error')
  reason             reason for the assigned status('OK', 'Quality below 50%', 'Quality below 80%', 'Nothing was attempted') 
  node               node-name
  max_pend_bytes     Max. number of bytes pending for transfer in the interval under examination
  cur_quality        Quality for transfer
  cur_pend_bytes     Number of bytes currently pending for transfer

=head3 <nesteddata> attributes

  quality          quality of transfers in the current timebin
  failed           number of failed transfer
  done             number of done transfer
  pend_bytes       number of bytes queued for transfer in the current timebin
  timebin          Unix epoch time of start of current timebin

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
sub duration { return 3600 - time%3600 + 60; } # Just after the top of the hour
sub invoke { return _shift_queuedquality(@_); }

sub _shift_queuedquality
{
  my ($core, %h) = @_;
  my ($epochHours,$start,$end,$node,%params,%paramsq,$qualtiy,$queue,$mindata);
  my ($h,$noblocks,$quality,$cycle,$nConsecFail,$nConsecOK,$nConsecWarn);
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
  %paramsq = ( ':starttime' => $start, ':endtime' => $end );
  
  # don't need aggregation for T1 Buffer and MSS here
  $h->{NOAGGREGATE} = 1;
  map { $h{uc $_} = uc delete $h{$_} } keys %h;
  $queue = PHEDEX::Web::API::Shift::Queued::getShiftPending($core,\%params,\%h);
  $quality = PHEDEX::Web::API::Shift::Quality::getShiftQuality($core,\%paramsq,\%h);

  $mindata = $h{MINDATA} || 1024*1024*1024*1024;

  $unique = 0;

  foreach $node ( keys %{$queue} )
  {
    foreach $bin ( keys %{$queue->{$node}} )
    {
      $queue->{$node}{$bin}{DONE} = $quality->{$node}{$bin}{DONE};
      $queue->{$node}{$bin}{FAILED} = $quality->{$node}{$bin}{FAILED};
      if ( $queue->{$node}{$bin}{DONE} || $queue->{$node}{$bin}{FAILED} )
      {
         $queue->{$node}{$bin}{QUALITY} = int(1000*$quality->{$node}{$bin}{QUALITY})/10;
      }
    }
  }

  foreach $node ( keys %{$queue} )
  {
    if ( ! $s{$node} )
    {
      $s{$node} = {
			 NODE			=> $node,
			 MAX_PEND_BYTES		=> 0,
			 CUR_PEND_BYTES		=> 0,
			 CUR_QUALITY    	=> 0,
			 TIMEBINS		=> {},
			 STATUS			=> 0,
			 REASON			=> 'OK',
			 NESTEDDATA		=> [],
			 UNIQUEID		=> $unique++,
		  };
    }
    $s{$node}{TIMEBINS} = $queue->{$node};
  }

  foreach $node ( keys %s )
  {
    $nConsecFail  = $nConsecOK = $noblocks = $cycle = 0;
    foreach $bin ( sort { $a <=> $b } keys %{$s{$node}{TIMEBINS}} )
    {
      $e = $s{$node}{TIMEBINS}{$bin};
      $e->{TIMEBIN} += 0; # numify for JSON encoder
      if ( $s{$node}{MAX_PEND_BYTES} < $e->{PEND_BYTES} )
         { $s{$node}{MAX_PEND_BYTES} = $e->{PEND_BYTES}; }

      $s{$node}{CUR_PEND_BYTES}    = $e->{PEND_BYTES};
      $s{$node}{CUR_QUALITY} = $e->{QUALITY};

      #if (( ! $e->{DONE} )&& ( ! $e->{FAILED} )) { $nConsecFail = 0; }
    
      if ( defined($e->{QUALITY}))
      {
        $quality = $e->{QUALITY};
        if ( $quality < 0.5 ) { $nConsecFail++; }
        else                { $nConsecFail=0; }
        if ( $quality >= 0.8 ) { $nConsecOK++; }
        else                              { $nConsecOK=0;  }
        if ( $quality >= 0.5 && $quality < 0.8 ) { $nConsecWarn++; }
        else              { $nConsecWarn=0;  }
        $noblocks = 0;
      }
      else {
        $noblocks++;
      }
      $cycle++;
      if ( $nConsecWarn >= 4 )
      {
        $s{$node}{STATUS} = 1;
        $s{$node}{REASON} = 'quality is below 80%';
      }
      if ( $nConsecFail >= 4 )
      {
        $s{$node}{STATUS} = 2;
        $s{$node}{REASON} = 'quality is below 50%';
      }
      if ( $noblocks >= 4 ) {
        $s{$node}{STATUS} = 2;
        $s{$node}{REASON} = 'nothing was attempted';
      }
      if ( $nConsecOK >= 3 && $s{$node}{STATUS} )
      {
        $s{$node}{STATUS} = 1;
        $s{$node}{REASON} = 'queue may fail';
      }
      delete $e->{NODE};
      push @{$s{$node}{NESTEDDATA}},$e;
    }

#   Sanity check...
    if ( !defined $s{$node}{REASON} )
    {
      die "REASON not defined for $node. Have you changed the algorithm?";
    }
    $s{$node}{STATUS_TEXT} = $status_map->{$s{$node}{STATUS}};
    $s{$node}{STATUS} += 0; # numification :-(
    delete $s{$node}{TIMEBINS};
    # don't need to take T1 MSS into account
    delete $s{$node} if ( $node =~ m%^T1_(.*)_MSS$% );
    delete $s{$node} if ( !$s{$node}{STATUS} && !$h{FULL} );
  }

  my @r = values %s;
  return { queuedquality => \@r };
}

1;
