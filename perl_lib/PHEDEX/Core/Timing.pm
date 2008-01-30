package PHEDEX::Core::Timing;

=head1 NAME

PHEDEX::Core::Timing - a drop-in replacement for Toolkit/UtilsTiming

=cut

use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw(mytimeofday formatTime timeStart elapsedTime formatElapsedTime);
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

1;
