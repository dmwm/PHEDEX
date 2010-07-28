package PHEDEX::Web::API::Shift::Requested;
use PHEDEX::Core::DB;

use warnings;
use strict;

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
sub duration { return 600; }
sub invoke { return _shift_requested(@_); }

sub _shift_requested
{
  my ($core, %h) = @_;
  my $epochHours = int(time/3600);
  my $start = ($epochHours-12) * 3600;
  my $end   =  $epochHours     * 3600;
  my $node  = 'T%';
  my %params = ( ':starttime' => $start, ':endtime' => $end, ':node' => $node );

  my $q = getShiftRequested( $core,%params);
  return { requested => \$q };
}

sub getShiftRequested
{
  my ($core,%params) = @_;
  my $r;
  my $sql = qq{
    select
      t.name node,
      trunc(h.timebin/3600)*3600 timebin,
      nvl(sum(h.request_bytes) keep (dense_rank last order by timebin asc),0) request_bytes
    from t_history_dest h
      join t_adm_node t on t.id = h.node
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
