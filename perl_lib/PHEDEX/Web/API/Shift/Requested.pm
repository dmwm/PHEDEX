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

  my $q = getShiftRequested($core,\%params,\%h);
  return { requested => $q };
}

sub getShiftRequested
{
  my ($core,$params,$h) = @_;
  my ($r,$sql,$span);

  map { $h->{uc $_} = uc delete $h->{$_} } keys %$h;
  $span = $h->{SPAN} || 3600;
  $sql = qq{
    select
      t.name node,
      trunc(h.timebin/$span)*$span timebin,
      nvl(sum(h.request_bytes) keep (dense_rank last order by timebin asc),0) request_bytes
    from t_history_dest h
      join t_adm_node t on t.id = h.node
    where timebin >= :starttime
      and timebin < :endtime
      and t.name like :node
    group by trunc(h.timebin/$span)*$span, t.name
    order by 1 asc, 2 };

  my $q = &dbexec($core->{DBH}, $sql,% {$params});
  while (my $row = $q->fetchrow_hashref())
  { $r->{$row->{NODE} . '+' . $row->{TIMEBIN}} = $row; }

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
        $r->{$j}{REQUEST_BYTES} = 0;
      }
      $r->{$j}{REQUEST_BYTES} += $r->{$i}{REQUEST_BYTES};
      delete $r->{$i};
    }
  }

  return $r;
}

1;
