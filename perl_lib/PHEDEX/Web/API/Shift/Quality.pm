package PHEDEX::Web::API::Shift::Quality;
use PHEDEX::Core::DB;

use warnings;
use strict;

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
sub duration { return 600; }
sub invoke { return _shift_quality(@_); }

sub _shift_quality
{
  my ($core, %h) = @_;
  my $epochHours = int(time/3600);
  my $start = ($epochHours-12) * 3600;
  my $end   =  $epochHours     * 3600;
  my %params = ( ':starttime' => $start, ':endtime' => $end );

  my $p = getShiftQuality($core,\%params,\%h);
  return { quality => $p };
}

sub getShiftQuality
{
  my ($core,$params,$h) = @_;
  my ($row,$r,$q,$sql);
  my ($dir,$span,$to,$from);
  map { $h->{uc $_} = uc delete $h->{$_} } keys %$h;
  $dir  = $h->{DIR} || 'FROM';
  $span = $h->{SPAN} || 3600;
  $sql = qq{
        select
          f.name from_node, t.name to_node,
          trunc( h.timebin/$span)*$span timebin,
            nvl(sum(h.done_files),0)   done,
            nvl(sum(h.fail_files),0)   failed,
            nvl(sum(h.try_files),0)    tried,
            nvl(sum(h.expire_files),0) expired
        from t_history_link_events h
          join t_adm_node f on f.id = h.from_node
          join t_adm_node t on t.id = h.to_node
        where timebin >= :starttime
          and timebin < :endtime
        group by trunc(h.timebin/$span)*$span,
          f.name, t.name order by 1 asc, 2, 3
    };
  $q = &dbexec($core->{DBH}, $sql,%{$params});

  while ($row = $q->fetchrow_hashref())
  {
    if ( $row->{DONE} )
    {
      $row->{QUALITY} = $row->{DONE}/($row->{DONE}+$row->{FAILED});
    }
    $to   = delete $row->{TO_NODE};
    $from = delete $row->{FROM_NODE};
    if ( $dir eq 'FROM' )
    {
      $r->{$from}{$to}  {$row->{TIMEBIN}} = $row;
    } else {
      $r->{$to}  {$from}{$row->{TIMEBIN}} = $row;
    }
  }
  return $r;
}

1;
