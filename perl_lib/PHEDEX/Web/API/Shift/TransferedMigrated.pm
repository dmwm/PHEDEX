package PHEDEX::Web::API::Shift::TransferedMigrated;
use PHEDEX::Core::DB;
use PHEDEX::Web::API::Shift::Transfered;

use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Shift::TransferedMigrated - Transfered vs. Migrated data analysis for shift personnel.

=head1 DESCRIPTION

Serves information about current activity in PhEDEx. This module is
specifically tailored to suit the needs of people on shift who are checking
that data is moving properly.

The code implements a check if migrated data is failing or not attempted
for that node. 

It gets the number of bytes transfered and migrated for each T2 node for 
each of the last 12 hours, with timebins aligned on the hour.
If data was transfered in a given hour, and for four hours following that hour 
no migration appear, nothing was attempted,then the node is likely to have a problem, and put into error status.
If Migrated/Transfered < 30% AND Transfered > 50 GB when summed over the last four hours,
then the node is considered to migrate too slow, and put into warning status.


N.B. Only T1 sitess are taken into account. 


=head2 Options

 required inputs: none
 optional inputs: (as filters) node

 full            show information about all nodes, not just those with a problem

=head2 Output

  <transferedmigrated>
    <nesteddata/>
  </transferedmigrated>
  ...

=head3 <transferedmigrated> attributes

  status             status-code (numeric). 0 => OK, 1 => possible problem, 2 => problem
  status_text        textual representation of the status ('OK', 'Warn', 'Error')
  reason             reason for the assigned status('OK', 'migration may be too slow (migrated/transfered < 30%)', 'Nothing was attempted') 
  node               node-name
  max_done_bytes     Max. number of bytes transfered in the interval under examination
  cur_done_bytes     Number of bytes currently transfered 

=head3 <nesteddata> attributes

  done_bytes             number of done transfer
  migrated_bytes         number of bytes migrated in the current timebin
  timebin                Unix epoch time of start of current timebin

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
sub duration { return 3600 - time%3600 + 60; } # Just after the top of the hour
sub invoke { return _shift_transferedmigrated(@_); }

sub _shift_transferedmigrated
{
  my ($core, %h) = @_;
  my ($epochHours,$start,$end,$node,$nodeMSS,%params,$transfer,$mindata);
  my ($h,$noblocks,$ratio);
  my (%s,$bin,$unique,$e,$eMSS,$buffer,$i,$j,$k,$status_map,$transfered,$migrated,$sum_transfered,$sum_migrated);

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
  
  # don't need aggregation for T1 Buffer and MSS here
  $h{NOAGGREGATE} = 1;
  map { $h{uc $_} = uc delete $h{$_} } keys %h;
  $transfer = PHEDEX::Web::API::Shift::Transfered::getShiftTransfered($core,\%params,\%h);

  $mindata = $h{MINDATA} || 1024*1024*1024*1024;

  $unique = 0;

  foreach $node ( keys %{$transfer} )
  {
    if ( $node =~ m%^T1_(.*)_Buffer$% ) {
       if ( ! $s{$node} )
       {
          $s{$node} = {
			 NODE			=> $node,
			 MAX_DONE_BYTES		=> 0,
			 CUR_DONE_BYTES		=> 0,
			 TIMEBINS		=> {},
                         MSSTIMEBINS            => {},
			 STATUS			=> 0,
			 REASON			=> 'OK',
			 NESTEDDATA		=> [],
			 UNIQUEID		=> $unique++,
		       };
       }
       $s{$node}{TIMEBINS} = $transfer->{$node};
       $nodeMSS = 'T1_' . $1 . '_MSS';
       $s{$node}{MSSTIMEBINS} = $transfer->{$nodeMSS}; 
     }
  }

  foreach $node ( keys %s )
  {
    $noblocks = 0;
    $i=0;
    $ratio = 1;
    foreach $bin ( sort { $a <=> $b } keys %{$s{$node}{TIMEBINS}} )
    {   
        $e = $s{$node}{TIMEBINS}{$bin};
        $e->{TIMEBIN} += 0; # numify for JSON encoder
        $eMSS = $s{$node}{MSSTIMEBINS}{$bin};
        $e->{MIGRATED_BYTES} = $eMSS->{DONE_BYTES};
        if ( $s{$node}{MAX_DONE_BYTES} < $e->{DONE_BYTES} )
        { $s{$node}{MAX_DONE_BYTES} = $e->{DONE_BYTES}; }

        $s{$node}{CUR_DONE_BYTES}    = $e->{DONE_BYTES};

 
        $sum_transfered = $transfered->[$i] =  $e->{DONE_BYTES}; 
        $sum_migrated = $migrated->[$i] = $eMSS->{DONE_BYTES};
       

        if ( $i>=3 ) {
           $sum_transfered = $transfered->[$i-1] + $transfered->[$i-2] + $transfered->[$i-3] + $transfered->[$i];
           $sum_migrated = $migrated->[$i-1] + $migrated->[$i-2] + $migrated->[$i-3] + $migrated->[$i];
        }
        if ( $sum_transfered ) {
           $ratio = $sum_migrated/$sum_transfered; 
        }

        if ( $eMSS->{DONE_BYTES} )
        {
           $noblocks = 0;
        }
        else {
           $noblocks++;
        }

        if (( $sum_transfered > 50*1024*1024*1024 ) && ( $ratio < 0.3 )) 
        {
           $s{$node}{STATUS} = 1;
           $s{$node}{REASON} = 'migration may be too slow and migration is less than 0.3 of transfered';
        }
        if ( $noblocks >= 4 ) {
           $s{$node}{STATUS} = 2;
           $s{$node}{REASON} = 'nothing was attempted';
        }
       delete $e->{NODE};
       push @{$s{$node}{NESTEDDATA}},$e;
       $i++;
    }

    #   Sanity check...
    if ( !defined $s{$node}{REASON} )
    {
       die "REASON not defined for $node. Have you changed the algorithm?";
    }
    $s{$node}{STATUS_TEXT} = $status_map->{$s{$node}{STATUS}};
    $s{$node}{STATUS} += 0; # numification :-(
    delete $s{$node}{TIMEBINS};
    delete $s{$node}{MSSTIMEBINS};
    delete $s{$node} if ( !$s{$node}{STATUS} && !$h{FULL} );
  }

  my @r = values %s;
  return { transferedmigrated => \@r };
}

1;
