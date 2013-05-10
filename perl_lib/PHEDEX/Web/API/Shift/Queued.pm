package PHEDEX::Web::API::Shift::Queued;
use PHEDEX::Core::DB;

use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Shift::Queued - Queued data summary

=head1 DESCRIPTION

Returns information about the data queued for each node in hourly 
timebins over the last 12 hours. Timebins are aligned to the start of the 
hour, not on the current time, so the latest timebin may vary in size from 
0 to 3600 seconds.

T1 sites are aggregated by _Buffer and _MSS.

=head2 Options

 required inputs: none
 optional inputs: 
    NOAGGREGATE  T1 Buffer and MSS info need aggregation, or not

=head2 Output

  <queued>
    <node>
      <$timebin/>
    </node>
  </queued>
  ...

=head3 <queued> attributes

 ...none

=head3 <node> attributes

 ...none

=head3 <$timebin> attributes

  pend_types    number of bytes pending for transfer in the current timebin
  timebin       Unix epoch time of start of current timebin

  N.B. The $timebin elements are named for the actual timebin value, not 'timebin', the string. This break with convention is permitted in the 'shift' modules, for tighter integration with the next-gen website.

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
sub duration { return 600; }
sub invoke { return _shift_queued(@_); }

sub _shift_queued
{
  my ($core, %h) = @_;

  map { $h{uc $_} = uc delete $h{$_} } keys %h;
  my $epochHours = int(($h{ENDTIME} || time)/3600);
  my $start = ($epochHours-($h{NBINS}||12)) * 3600;
  my $end   =  $epochHours     * 3600;
  my $node  = $h{NODE} || 'T%';
  my %params = ( ':starttime' => $start, ':endtime' => $end, ':node' => $node );

  my $p = getShiftPending($core,\%params,\%h);
  return { queued => $p };
}

sub getShiftPending
{
  my ($core,$params,$h) = @_;
  my ($r,$sql,$span,$q,$row);
  my ($i,$node,$bin);

  $span = $h->{SPAN} || 3600;
  $sql = qq{
    select
      t.name node,
      trunc(h.timebin/$span)*$span timebin,
      nvl(sum(h.pend_bytes) keep (dense_rank last order by timebin asc),0) pend_bytes
    from t_history_link_stats h
      join t_adm_node t on t.id = h.to_node
    where timebin >= :starttime
      and timebin < :endtime
      and t.name like :node
    group by trunc(h.timebin/$span)*$span, t.name
    order by 1 asc, 2 };
  $q = &dbexec($core->{DBH}, $sql, %{$params});
  while ($row = $q->fetchrow_hashref())
  {
    $r->{$row->{NODE}}{$row->{TIMEBIN}} = $row;
    delete $row->{NODE};
  }

# Aggregate MSS+Buffer nodes, and merge the Queued and Requested data.
  if ( !$h->{NOAGGREGATE} )
  {
    foreach $i ( keys %{$r} )
    {
      if ( $i =~ m%^T1_(.*)_Buffer$% )
      {
        $node = 'T1_' . $1 . '_MSS';
        foreach $bin ( keys %{$r->{$i}} )
        {
          if ( !$r->{$node}{$bin} )
          {
            $r->{$node}{$bin} = $r->{$i}{$bin};
            $r->{$node}{$bin}{PEND_BYTES} = 0;
          }
          $r->{$node}{$bin}{PEND_BYTES} += $r->{$i}{$bin}{PEND_BYTES} || 0;
        }
        delete $r->{$i};
      }
    }
  }

  foreach $node ( keys %{$r} )
  {
    foreach $bin ( keys %{$r->{$node}} )
    {
      $r->{$node}{$bin}{TIMEBIN}    += 0; # numify for the JSON encoder
      $r->{$node}{$bin}{PEND_BYTES} += 0; # numify for the JSON encoder
    }
  }
  return $r;
}

1;
