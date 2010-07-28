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

  my $p = getShiftQuality($core,%params);
  return { quality => \$p };
}

sub getShiftQuality
{
  my ($core,%params,$h) = @_;
  my $r;
  my $span = $h->{span} || 3600;
  my $sql = qq{
        select
          f.name from_node, t.name to_node,
          trunc( h.timebin/$span)*$span timebin,
            nvl(sum(h.done_files),0)   done_files,
            nvl(sum(h.fail_files),0)   fail_files,
            nvl(sum(h.try_files),0)    try_files,
            nvl(sum(h.expire_files),0) expire_files
        from t_history_link_events h
          join t_adm_node f on f.id = h.from_node
          join t_adm_node t on t.id = h.to_node
        where timebin >= :starttime
          and timebin < :endtime
        group by trunc(h.timebin/$span)*$span,
          f.name, t.name order by 1 asc, 2, 3
    };
  my $q = &dbexec($core->{DBH}, $sql,%params);
  while (my $row = $q->fetchrow_hashref())
  {
    if ( $row->{DONE_FILES} )
    {
      $row->{QUALITY} = $row->{DONE_FILES}/($row->{DONE_FILES}+$row->{FAIL_FILES});
    }
    $r->{$row->{FROM_NODE}}{$row->{TO_NODE}}{$row->{TIMEBIN}} = $row;
  }

# Quality is done/(failed+done)

  return $r;
}

1;
