package PHEDEX::Web::API::DashboardStats;
use PHEDEX::Web::SQL;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::DashboardStats - simple debugging call

=head2 DashboardStats

Return the link-history tables, as used in the rate plots. 

=cut

sub duration { return 0; }
sub invoke { return DashboardStats(@_); }
sub DashboardStats
{
  my ($core,%args) = @_;
  my ($stats,$linkHistory,$span,$key,$row);

$DB::single=1;
  $linkHistory = PHEDEX::Web::SQL::getLinkHistory($core,%args);
  $span = $args{SPAN};
  $stats->{Totals} = $linkHistory->{T}{1};
  foreach my $key ( keys %{$linkHistory->{N}} )
  {
    foreach $row ( $linkHistory->{N}{$key} )
    {
      next unless $row->{FROM_NODE};
      $row->{QUALITY} = Quality($row);
      push @{$stats->{Link}},$row;
      foreach ( qw / DONE_BYTES DONE_FILES FAIL_FILES EXPIRE_FILES / )
      {
        $stats->{To}{  $row->{TO_NODE}  }{$_} += $row->{$_};
        $stats->{From}{$row->{FROM_NODE}}{$_} += $row->{$_};
      }
    }
  }

  foreach ( keys %{$stats->{To}} )
  {
    $stats->{To}{$_}{QUALITY} = Quality($stats->{To}{$_});
    $stats->{To}{$_}{RATE} = $stats->{To}{$_}{DONE_BYTES}/$span;
  }
  foreach ( keys %{$stats->{From}} )
  {
    $stats->{From}{$_}{QUALITY} = Quality($stats->{From}{$_});
    $stats->{From}{$_}{RATE} = $stats->{From}{$_}{DONE_BYTES}/$span;
  }

  return { DashboardStats => $stats };
}

sub Quality
{
  my $h = shift;
  my $sum = $h->{DONE_FILES} + $h->{FAIL_FILES} + $h->{EXPIRE_FILES};

  my $x = $h->{DONE_FILES} / $sum;
  return 3 if $x > 0.66;
  return 2 if $x > 0.33;
  return 1 if $x > 0;
  return 0;
}

1;
