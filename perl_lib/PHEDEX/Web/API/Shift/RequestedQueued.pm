package PHEDEX::Web::API::Shift::RequestedQueued;
use PHEDEX::Core::DB;
use PHEDEX::Web::API::Shift::Requested;
use PHEDEX::Web::API::Shift::Queued;

use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Shift::RequestedQueued - current activity in PhEDEx

=head1 DESCRIPTION

Serves information about current activity in PhEDEx.

=head2 Options

 required inputs: none
 optional inputs: (as filters) node, se, agent

  node             node name, could be multiple
  se               storage element name, could be multiple
  agent            agent name, could be multiple
  version          PhEDEx version
  update_since     updated since this time
  detail           show "code" information at file level *

=head2 Output

  * without option "detail"

  <node>
    <agent/>
  </node>
  ...

  * with option "detail"

  <node>
    <agent>
      <code/>
      ...
    </agent>
  </node>
  ...

=head3 <node> elements

  name             agent name
  node             node name
  host             host name

=head3 <agent> elements

  label            label
  state_dir        directory path ot the states
  version          rpm release or 'CVS'
  pid              process id
  time_update      time it was updated

=head3 <code> elements

  filename         file name
  filesize         file size (bytes)
  checksum         checksum
  rivision         CVS revision
  tag              CVS tag

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
sub duration { return 3600 - time%3600 + 60; } # Just after the top of the hour
sub invoke { return _shift_requestedqueued(@_); }

sub _shift_requestedqueued
{
  my ($core, %h) = @_;
  my ($epochHours,$start,$end,$node,%params,$p,$q,$mindata);
  my ($h,$ratio,$nConsecFail,$nConsecOK);
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
  $p = PHEDEX::Web::API::Shift::Queued::getShiftPending($core,\%params,\%h);
  $q = PHEDEX::Web::API::Shift::Requested::getShiftRequested($core,\%params,\%h);

  $mindata = $h{MINDATA} || 1024*1024*1024*1024;

  $unique = 0;
  foreach ( keys %{$q} )
  {
    $q->{$_}{RATIO} = 0;
    $q->{$_}{PEND_BYTES} = $p->{$_}{PEND_BYTES} || 0;
    if ( $q->{$_}{PEND_BYTES} )
    {
      $q->{$_}{RATIO} = $q->{$_}{REQUEST_BYTES} / $q->{$_}{PEND_BYTES};
    }
  }

  foreach ( values %{$q} )
  {
    $node = $_->{NODE};
    if ( ! $s{$node} )
    {
      $s{$node} = {
			 NODE			=> $node,
			 MAX_PEND_BYTES		=> 0,
			 MAX_REQUEST_BYTES	=> 0,
			 CUR_PEND_BYTES		=> 0,
			 CUR_REQUEST_BYTES	=> 0,
			 TIMEBINS		=> {},
			 STATUS			=> 0,
			 REASON			=> 'OK',
			 NESTEDDATA		=> [],
			 UNIQUEID		=> $unique++,
		       };
    }
    $s{$node}{TIMEBINS}{$_->{TIMEBIN}} = $_;
  }

  foreach $node ( keys %s )
  {
#   Declare a problem is there are four consecutive bins where data is
#   requested but less than 10% of that data is queued.
    $nConsecFail  = $nConsecOK = 0;
    foreach $bin ( sort { $a <=> $b } keys %{$s{$node}{TIMEBINS}} )
    {
      $e = $s{$node}{TIMEBINS}{$bin};
      $e->{TIMEBIN} += 0; # numify for JSON encoder
      if ( $s{$node}{MAX_PEND_BYTES} < $e->{PEND_BYTES} )
         { $s{$node}{MAX_PEND_BYTES} = $e->{PEND_BYTES}; }
      if ( $s{$node}{MAX_REQUEST_BYTES} < $e->{REQUEST_BYTES} )
         { $s{$node}{MAX_REQUEST_BYTES} = $e->{REQUEST_BYTES}; }

      $s{$node}{CUR_PEND_BYTES}    = $e->{PEND_BYTES};
      $s{$node}{CUR_REQUEST_BYTES} = $e->{REQUEST_BYTES};

      $ratio = 0;
      if ( ! $e->{REQUEST_BYTES} ) { $nConsecFail = 0; }
      if ( $e->{PEND_BYTES} )
      { $ratio = $e->{REQUEST_BYTES} / $e->{PEND_BYTES}; }
      if ( $ratio < 0.1 ) { $nConsecFail++; }
      else                { $nConsecFail=0; }
      if ( $ratio > 0.9 ) { $nConsecOK++; }
      else                { $nConsecOK=0;  }
      if ( $nConsecFail >= 4 )
      {
        $s{$node}{STATUS} = 2;
        $s{$node}{REASON} = 'Queue stuck';
      }
      if ( $nConsecOK >= 3 && $s{$node}{STATUS} )
      {
        $s{$node}{STATUS} = 1;
        $s{$node}{REASON} = 'Queue may be stuck';
      }
      delete $e->{NODE};
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
      die "REASON not defined for $node. Have you changed the algorithm?\n";
    }
    $s{$node}{STATUS_TEXT} = $status_map->{$s{$node}{STATUS}};
    $s{$node}{STATUS} += 0; # numification :-(
    delete $s{$node}{TIMEBINS};
    delete $s{$node} if ( !$s{$node}{STATUS} && !$h{FULL} );
  }

  my @r = values %s;
  return { requestedqueued => \@r };
}

1;
