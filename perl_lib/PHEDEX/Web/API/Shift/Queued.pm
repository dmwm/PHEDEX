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
$DB::single=1;
  my ($core, %h) = @_;
  my $epochHours = int(time/3600);
  my $start = ($epochHours-12) * 3600;
  my $end   =  $epochHours     * 3600;
  my $node  = 'T%';
  my %params = ( ':starttime' => $start, ':endtime' => $end, ':node' => $node );

  my $p = getShiftPending($core,%params);
  return { queued => $p };
}

sub getShiftPending
{
  my ($core,%params) = @_;
  my $r;
  my $sql = qq{
    select
      t.name node,
      trunc(h.timebin/3600)*3600 timebin,
      nvl(sum(h.pend_bytes) keep (dense_rank last order by timebin asc),0) pend_bytes
    from t_history_link_stats h
      join t_adm_node t on t.id = h.to_node
    where timebin >= :starttime
      and timebin < :endtime
      and t.name like :node
    group by trunc(h.timebin/3600)*3600, t.name
    order by 1 asc, 2 };
  my $q = &dbexec($core->{DBH}, $sql,%params);
  while (my $row = $q->fetchrow_hashref())
  { $r->{$row->{NODE} . '+' . $row->{TIMEBIN}} = $row; }

  return $r;
}

1;
