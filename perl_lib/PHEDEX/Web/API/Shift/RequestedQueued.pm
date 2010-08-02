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
sub duration { return 60 * 60; }
sub invoke { return _shift_requestedqueued(@_); }

sub _shift_requestedqueued
{
  my ($core, %h) = @_;
  my ($epochHours,$start,$end,$node,%params,$p,$q,$mindata);
  my ($h,$ratio,$nConsecFail,$nConsecOK);
  my (%s,$bin,$unique,$e,$buffer,$i,$j,$k);

  $epochHours = int(time/3600);
  $start = ($epochHours-12) * 3600;
  $end   =  $epochHours     * 3600;
  $node  = 'T%';
  %params = ( ':starttime' => $start, ':endtime' => $end, ':node' => $node );
  $p = PHEDEX::Web::API::Shift::Queued::getShiftPending($core,%params);
  $q = PHEDEX::Web::API::Shift::Requested::getShiftRequested( $core,%params);

  map { $h{uc $_} = uc delete $h{$_} } keys %h;
  $mindata = $h{MINDATA} || 1024*1024*1024*1024;

# Aggregate MSS+Buffer nodes, and merge the Queued and Requested data.
  foreach $i ( keys %{$q} )
  {
    if ( $i =~ m%^T1_(.*)_Buffer\+(\d+)$% )
    {
      $node = 'T1_' . $1 . '_MSS';
      $bin = $2;
      $j = $node . '+' . $bin;
      if ( !$q->{$j} )
      {
        $q->{$j}{TIMEBIN} = $q->{$bin};
        $q->{$j}{NODE}    = $node;
        $q->{$j}{REQUEST_BYTES} = 0;
        $q->{$_}{PEND_BYTES} = 0;
      }
      $q->{$j}{REQUEST_BYTES} += $q->{$i}{REQUEST_BYTES};
      $q->{$j}{PEND_BYTES}    += $p->{$j}{PEND_BYTES} || 0;
      delete $q->{$i};
    }
  }

  $unique = 0;
  foreach ( keys %{$q} )
  {
    $q->{$_}{RATIO} = 0;
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
			 STATUS			=> 'OK',
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
    foreach $bin ( sort keys %{$s{$node}{TIMEBINS}} )
    {
      $e = $s{$node}{TIMEBINS}{$bin};
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
        $s{$node}{STATUS} = 'Problem';
        $s{$node}{REASON} = 'Queue stuck';
      }
      if ( $nConsecOK >= 3 && $s{$node}{STATUS} ne 'OK' )
      {
        $s{$node}{REASON} = 'Queue may have been stuck';
      }
      delete $e->{NODE};
      push @{$s{$node}{NESTEDDATA}},$e;
    }

    if ( $s{$node}{MAX_REQUEST_BYTES} < $mindata )
    {
      $s{$node}{STATUS} = 'OK';
      $s{$node}{REASON} = 'very little data requested';
    }
    if ( !$s{$node}{MAX_REQUEST_BYTES} )
    {
      $s{$node}{STATUS} = 'OK';
      $s{$node}{REASON} = 'no data requested';
    }
    delete $s{$node}{TIMEBINS};
    delete $s{$node} if ( $s{$node}{STATUS} eq 'OK' && !$h{FULL} );
  }

  my @r = values %s;
  return { requestedqueued => \@r };
}

1;
