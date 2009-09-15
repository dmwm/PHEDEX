package PHEDEX::Core::Timing;

=head1 NAME

PHEDEX::Core::Timing - a drop-in replacement for Toolkit/UtilsTiming

=cut

use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw(mytimeofday formatTime formatTimespan age timeStart elapsedTime formatElapsedTime timeSub);
use Time::HiRes 'gettimeofday';
use POSIX qw(strftime);


# High-resolution timing.
sub mytimeofday
{
    return scalar (&gettimeofday());
}

# Format TIME as unit of RANGE ("hour", "day", "week" or "month").
sub formatTime
{
  my ($time, $range) = @_;
  return undef unless ($time && $range);
  return undef if ($time <= 0);
  if ($range eq 'hour') { return strftime ('%Y%m%dZ%H00', gmtime(int($time))); }
  elsif ($range eq 'day') { return strftime ('%Y%m%d', gmtime(int($time))); }
  elsif ($range eq 'week') { return strftime ('%Y%V', gmtime(int($time))); }
  elsif ($range eq 'month') { return strftime ('%Y%m', gmtime(int($time))); }
  elsif ($range eq 'stamp') { return strftime ('%Y-%m-%d %H:%M:%S UTC', gmtime(int($time))); }
  elsif ($range eq 'http') { return strftime("%a, %d %b %Y %H:%M:%S UTC", gmtime(int($time))); }
}

# Convert a time span into human-friendly long string.
sub formatTimespan
{
  my $span = shift;
  if ($span >= 86400)
  {
    $span /= 86400;
    return $span == 1 ? "day" : "$span days";
  }
  elsif ($span >= 3600)
  {
    $span /= 3600;
    return $span == 1 ? "hour" : "$span hours";
  } elsif ($span >= 60) {
    $span /= 60;
    return $span == 1 ? "minute" : "$span minutes";
  } else {
    return $span == 1 ? "second" : "$span seconds";
  }
}

# Convert a time difference into human-friendly short age string.
sub age
{
  my ($diff, $precision) = @_;
  $precision = 'minute' if !defined $precision;
  if (! grep ($precision eq $_, qw(second minute)) ) {
      die "Bad args to age()\n";
  }

  my $str = "";
  my $full = 0;

  if ($precision ne 'minute' &&  abs($diff) <= 3600) {
      $str .= sprintf("%dm", $diff / 60);
      $diff %= 60;
      $str .=  sprintf("%02d", $diff);
      return $str;
  }

  if (abs($diff) >= 86400)
  {
    $str .= sprintf("%dd", $diff / 86400);
    $diff %= 86400;
    $full = 1;
  }
  $str .= sprintf("%dh", $diff / 3600);
  $diff %= 3600;
  $str .= sprintf("%02d", $diff / 60);
  return $str;
}

sub timeStart
{
    my ($array) = @_;
    @$array = (&mytimeofday, times);
}

sub elapsedTime 
{
    my ($start) = @_;
    my @now = (&mytimeofday, times);
    my @old = @$start;
    return ($now [0] - $old [0], $now[3] - $old [3], $now[4] - $old [4]);
}

sub formatElapsedTime
{
    return sprintf ("%.2fr %.2fu %.2fs", &elapsedTime(@_));
}

sub timeSub
{
    my ($coderef, $label, @args) = @_;
    my @r;
    my $t1 = &mytimeofday();
    if (wantarray) {
	@r = &$coderef(@args);
    } else {
	$r[0] = &$coderef(@args);
    }
    my $t2 = &mytimeofday();
    print STDERR "timing: $label: ", sprintf("%.6f s", $t2-$t1), "\n";
    return wantarray ? @r : $r[0];
}

1;
