package PHEDEX::Web::API::Shift::Idle;
use PHEDEX::Core::DB;

use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Shift::Idle - Idle data summary

=head1 DESCRIPTION

Returns information about the data idle for each node in hourly 
timebins over the last 12 hours. Timebins are aligned to the start of the 
hour, not on the current time, so the latest timebin may vary in size from 
0 to 3600 seconds.

T1 sites are aggregated by _Buffer and _MSS.

=head2 Options

 required inputs: none

=head2 Output

  <requested>
    <node>
      <$timebin/>
    </node>
  </requested>
  ...

=head3 <requested> attributes

 ...none

=head3 <node> attributes

 ...none

=head3 <$timebin> attributes

  idle_bytes       number of bytes idle for transfer in the current timebin
  timebin          Unix epoch time of start of current timebin

  N.B. The $timebin elements are named for the actual timebin value, not 'timebin', the string. This break with convention is permitted in the 'shift' modules, for tighter integration with the next-gen website.

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
sub duration { return 600; }
sub invoke { return _shift_requested(@_); }

sub _shift_requested
{
  my ($core, %h) = @_;
  map { $h{uc $_} = uc delete $h{$_} } keys %h;
  my $epochHours = int(($h{ENDTIME} || time)/3600);
  my $start = ($epochHours-($h{NBINS}||12)) * 3600;
  my $end   =  $epochHours     * 3600;
  my $node  = $h{NODE} || 'T%';
  my %params = ( ':starttime' => $start, ':endtime' => $end, ':node' => $node );

  my $q = getShiftIdle($core,\%params,\%h);
  return { requested => $q };
}

sub getShiftIdle
{
  my ($core,$params,$h) = @_;
  my ($r,$sql,$span,$q,$row);
  my ($i,$node,$bin);

  $span = $h->{SPAN} || 3600;
  $sql = qq{
    select
      t.name node,
      trunc(h.timebin/$span)*$span timebin,
      nvl(sum(h.idle_bytes) keep (dense_rank last order by timebin asc),0) idle_bytes
    from t_history_dest h
      join t_adm_node t on t.id = h.node
    where timebin >= :starttime
      and timebin < :endtime
      and t.name like :node
    group by trunc(h.timebin/$span)*$span, t.name
    order by 1 asc, 2 };

  $q = &dbexec($core->{DBH}, $sql,% {$params});
  while ($row = $q->fetchrow_hashref())
  {
    $r->{$row->{NODE}}{$row->{TIMEBIN}} = $row; 
    $row->{TIMEBIN} += 0; # numify for the JSON encoder
    $row->{IDLE_BYTES} += 0; # numify for the JSON encoder
    delete $row->{NODE};
  }

# Aggregate MSS+Buffer nodes, and merge the Idle data.
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
            $r->{$node}{$bin}{IDLE_BYTES} = 0;
          }
          $r->{$node}{$bin}{IDLE_BYTES} += $r->{$i}{$bin}{IDLE_BYTES};
        }
        delete $r->{$i};
      }
    }
  }

  return $r;
}

1;
