package PHEDEX::Web::API::Shift::Quality;
use PHEDEX::Core::DB;

use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Shift::Quality - Quality data summary

=head1 DESCRIPTION

Returns information about the quality for transfer to each node in hourly
timebins over the last 12 hours. Timebins are aligned to the start of the
hour, not on the current time, so the latest timebin may vary in size from
0 to 3600 seconds.

T1 sites are aggregated by _Buffer and _MSS.

=head2 Options

 required inputs: none
 optional inputs: 
    NOAGGREGATE   T1 Buffer and MSS info need aggregation, or not  

=head2 Output

  <quality>
    <node>
      <$timebin/>
    </node>
  </quality>
  ...

=head3 <quality> attributes

 ...none

=head3 <node> attributes

 ...none

=head3 <timebin> attributes

  TRIED      number of tried transfer  
  FAILED     number of failed transfer
  DONE       number of done transfer
  EXPIRED    number of expired transfer
  QUALITY    quality of transfers, defined as DONE/(FAILED+DONE) 
=cut

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
  my ($row,$r,$q,$qr,$sql,$i);
  my ($dir,$span,$to,$from,$node,$bin,$num);
  map { $h->{uc $_} = uc delete $h->{$_} } keys %$h;
  $dir  = $h->{DIR} || 'TO';
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
    #if ( $row->{DONE} )
    #{
    #  $row->{QUALITY} = $row->{DONE}/($row->{DONE}+$row->{FAILED});
    #}
    # How to define quality?
    if (( $row->{DONE} ) || ( $row->{FAILED} ))
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

  $qr = {};
  foreach $to ( keys %{$r} )
  {
    foreach $from ( keys %{$r->{$to}} )
    {
      foreach $bin ( keys %{$r->{$to}->{$from}} )
      {
         $qr->{$to}{$bin}{DONE} +=$r->{$to}{$from}{$bin}{DONE};
         $qr->{$to}{$bin}{FAILED} +=$r->{$to}{$from}{$bin}{FAILED};
         $qr->{$to}{$bin}{TRIED} +=$r->{$to}{$from}{$bin}{TRIED};
         $qr->{$to}{$bin}{EXPIRED} +=$r->{$to}{$from}{$bin}{EXPIRED};
      }
    }
    foreach $bin ( keys %{$qr->{$to}} )
    {
       if (( $qr->{$to}{$bin}{DONE} )||($qr->{$to}{$bin}{FAILED})) {
           $qr->{$to}{$bin}{QUALITY} = $qr->{$to}{$bin}{DONE}/($qr->{$to}{$bin}{DONE}+$qr->{$to}{$bin}{FAILED});
       }
    }
  }

# Aggregate MSS+Buffer nodes, and merge the quality
  if ( !$h->{NOAGGREGATE} )
  {
    foreach $i ( keys %{$qr} )
    {
      if ( $i =~ m%^T1_(.*)_Buffer$% )
      {
        $node = 'T1_' . $1 . '_MSS';
        foreach $bin ( keys %{$qr->{$i}} )
        {
          if ( !$qr->{$node}{$bin} )
          {
            #$qr->{$node}{$bin} = $qr->{$i}{$bin};
            $qr->{$node}{$bin}{DONE} = 0;
            $qr->{$node}{$bin}{FAILED} = 0;
            $qr->{$node}{$bin}{TRIED} = 0;
            $qr->{$node}{$bin}{EXPIRED} = 0;
          }
          $qr->{$node}{$bin}{DONE} += $qr->{$i}{$bin}{DONE};
          $qr->{$node}{$bin}{FAILED} += $qr->{$i}{$bin}{FAILED};
          $qr->{$node}{$bin}{TRIED} += $qr->{$i}{$bin}{TRIED};
          $qr->{$node}{$bin}{EXPIRED} += $qr->{$i}{$bin}{EXPIRED};
          if ( $qr->{$node}{$bin}{DONE}||$qr->{$node}{$bin}{FAILED}) 
          {
             $qr->{$node}{$bin}{QUALITY} = $qr->{$node}{$bin}{DONE}/($qr->{$node}{$bin}{DONE}+$qr->{$node}{$bin}{FAILED});
          }
        }
        delete $qr->{$i};
      }
    }
  }


  #return $r;
  return $qr;
}

1;
