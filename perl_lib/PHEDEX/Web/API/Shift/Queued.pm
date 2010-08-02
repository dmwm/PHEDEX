package PHEDEX::Web::API::Shift::Queued;
use PHEDEX::Core::DB;

use warnings;
use strict;

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
sub duration { return 600; }
sub invoke { return _shift_queued(@_); }

sub _shift_queued
{
  my ($core, %h) = @_;
  my $epochHours = int(time/3600);
  my $start = ($epochHours-12) * 3600;
  my $end   =  $epochHours     * 3600;
  my $node  = 'T%';
  my %params = ( ':starttime' => $start, ':endtime' => $end, ':node' => $node );

  my $p = getShiftPending($core,\%params,\%h);
  return { queued => $p };
}

sub getShiftPending
{
  my ($core,$params,$h) = @_;
  my ($r,$sql,$span);

  map { $h->{uc $_} = uc delete $h->{$_} } keys %$h;
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
  my $q = &dbexec($core->{DBH}, $sql, %{$params});
  while (my $row = $q->fetchrow_hashref())
  {
    $r->{$row->{NODE} . '+' . $row->{TIMEBIN}} = $row;
    $row->{TIMEBIN} += 0; # numify for the JSON encoder
    $row->{PEND_BYTES} += 0; # numify for the JSON encoder
  }

  return $r if $h->{NOAGGREGATE};
# Aggregate MSS+Buffer nodes, and merge the Queued and Requested data.
  my ($i,$j,$node,$bin);
  foreach $i ( keys %{$r} )
  {
    if ( $i =~ m%^T1_(.*)_Buffer\+(\d+)$% )
    {
      $node = 'T1_' . $1 . '_MSS';
      $bin = $2;
      $j = $node . '+' . $bin;
      if ( !$r->{$j} )
      {
        $r->{$j}{TIMEBIN} = $r->{$bin};
        $r->{$j}{NODE}    = $node;
        $r->{$_}{PEND_BYTES} = 0;
      }
      $r->{$j}{PEND_BYTES} += $r->{$i}{PEND_BYTES};
      delete $r->{$i};
    }
  }

  return $r;
}

1;
