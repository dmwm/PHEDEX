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
  my $epochHours = int(time/3600);
  my $start = ($epochHours-12) * 3600;
  my $end   =  $epochHours     * 3600;
  my $node  = 'T%';
  my %params = ( ':starttime' => $start, ':endtime' => $end, ':node' => $node );
  my $p = PHEDEX::Web::API::Shift::Queued::getShiftPending($core,%params);
  my $q = PHEDEX::Web::API::Shift::Requested::getShiftRequested( $core,%params);

  my (%s,$bin,$unique);
  $unique = 0;
  foreach ( keys %{$q} )
  {
    $q->{$_}{PEND_BYTES} = $p->{$_}{PEND_BYTES} || 0;
    $q->{$_}{RATIO} = 0;
    if ( $q->{$_}{PEND_BYTES} )
    {
      $q->{$_}{RATIO} = $q->{$_}{REQUEST_BYTES} / $q->{$_}{PEND_BYTES};
    }
  }

  foreach ( values %{$q} )
  {
    if ( ! $s{$_->{NODE}} )
    {
      $s{$_->{NODE}} = {
			 NODE			=> $_->{NODE},
			 MAX_PEND_BYTES		=> 0,
			 MAX_REQUEST_BYTES	=> 0,
			 TIMEBINS		=> {},
			 STATUS			=> 'OK',
			 NESTEDDATA		=> [],
			 UNIQUEID		=> $unique++,
		       };
    }
    $s{$_->{NODE}}{TIMEBINS}{$_->{TIMEBIN}} = $_;
  }

  my ($h,$ratio,$nConsecFail,$nConsecOK);
  foreach $node ( keys %s )
  {
#   Declare a problem is there are four consecutive bins where data is
#   requested but less than 10% of that data is queued.
    $nConsecFail  = $nConsecOK = 0;
    foreach $bin ( sort keys %{$s{$node}{TIMEBINS}} )
    {
      $h = $s{$node}{TIMEBINS}{$bin};
      if ( $s{$node}{MAX_PEND_BYTES} < $h->{PEND_BYTES} )
         { $s{$node}{MAX_PEND_BYTES} = $h->{PEND_BYTES}; }
      if ( $s{$node}{MAX_REQUEST_BYTES} < $h->{REQUEST_BYTES} )
         { $s{$node}{MAX_REQUEST_BYTES} = $h->{REQUEST_BYTES}; }

      $ratio = 0;
      if ( ! $h->{REQUEST_BYTES} ) { $nConsecFail = 0; }
      if ( $h->{PEND_BYTES} )
      { $ratio = $h->{REQUEST_BYTES} / $h->{PEND_BYTES}; }
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
      delete $h->{NODE};
      push @{$s{$node}{NESTEDDATA}},$h;
    }

    if ( $s{$node}{MAX_REQUEST_BYTES} < 1024*1024*1024 )
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
  }

  my @r = values %s;
  return { requestedqueued => \@r };
}

1;
