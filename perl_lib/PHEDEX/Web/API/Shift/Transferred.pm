package PHEDEX::Web::API::Shift::Transferred;
use PHEDEX::Core::DB;
use Data::Dumper;


use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Shift::Transferred - Transferred data summary

=head1 DESCRIPTION

Returns information about the data Transferred for each node in hourly 
timebins over the last 12 hours. Timebins are aligned to the start of the 
hour, not on the current time, so the latest timebin may vary in size from 
0 to 3600 seconds.


=head2 Options

 required inputs: none
 optional inputs: 
    NOAGGREGATE  T1 Buffer and MSS info need aggregation, or not

=head2 Output

  <done>
    <node>
      <$timebin/>
    </node>
  </done>
  ...

=head3 <done> attributes

 ...none

=head3 <node> attributes

 ...none

=head3 <$timebin> attributes

  done_bytes    number of bytes transferred in the current timebin
  timebin       Unix epoch time of start of current timebin

  N.B. The $timebin elements are named for the actual timebin value, not 'timebin', the string. This break with convention is permitted in the 'shift' modules, for tighter integration with the next-gen website.

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
sub duration { return 600; }
sub invoke { return _shift_transferred(@_); }

sub _shift_transferred
{
  my ($core, %h) = @_;

  my $epochHours = int(($h{ENDTIME} || time)/3600);
  my $start = ($epochHours-($h{NBINS}||12)) * 3600;
  my $end   =  $epochHours     * 3600;
  my $node  = $h{NODE} || 'T%';
  my %params = ( ':starttime' => $start, ':endtime' => $end, ':node' => $node );

  my $p = getShiftTransferred($core,\%params,\%h);
  return { transferred => $p };
}

sub getShiftTransferred
{
  my ($core,$params,$h) = @_;
  my ($r,$sql,$span,$q,$row);
  my ($i,$node,$bin);
  map { $h->{uc $_} = uc delete $h->{$_} } keys %$h;
  $span = $h->{SPAN} || 3600;

  $sql = qq{
    select
      t.name node,
      trunc(h.timebin/$span)*$span timebin,
      nvl(sum(h.done_bytes), 0) done_bytes
    from t_history_link_events h
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

# Aggregate MSS+Buffer nodes, and merge the transferred data.
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
            $r->{$node}{$bin}{DONE_BYTES} = 0;
          }
          $r->{$node}{$bin}{DONE_BYTES} += $r->{$i}{$bin}{DONE_BYTES} || 0;
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
      $r->{$node}{$bin}{DONE_BYTES} += 0; # numify for the JSON encoder
    }
  }
  return $r;
}

1;
