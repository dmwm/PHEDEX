package PHEDEX::Core::Timing;

use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw(mytimeofday gmmktime str2time formatTime formatTimespan age timeStart elapsedTime formatElapsedTime timeSub);
use Time::HiRes 'gettimeofday';
use POSIX qw(strftime mktime);


# High-resolution timing.
sub mytimeofday
{
    return scalar (&gettimeofday());
}

# Stolen from SEAL Time.cpp.  Convert broken down time (mktime format)
# into UTC time in seconds in UNIX epoch format.  Uses mktime in a way
# that returns UTC, not local time.
sub gmmktime
{
    my @args = @_;
    my $t1 = mktime (@args);
    my @gmt = gmtime ($t1);
    my $t2 = mktime (@gmt);
    return $t1 + ($t1 - $t2);
}

# str2time($str, $default) -- convert string to timestamp
#    When parsing fails, returns the defaul
#
# possible input values:
#    UNIX time
#    YYYY-MM-DD[_hh:mm:ss]
#    now
#    last_hour
#    last_12hours
#    last_day
#    last_7days
#    last_week
#    last_30days
#    last_180days
sub str2time
{
    my ($str, $default) = @_;
    my @dh;
    my @t;

    if ($str =~ m!(^\d*$)!)	# UNIX time
    {
        return $str;
    }
    elsif ($str =~ m!(^\d*\.\d*$)!)	# UNIX time in float
    {
        return int($str);
    }
    elsif (@dh = $str =~ m!(^-{0,1}\d*)d$!)	# number of days
    {
        return time() + int($dh[0])*3600*24;
    }
    elsif (@dh = $str =~ m!(^-{0,1}\d*)h$!)	# number of hours
    {
        return time() + int($dh[0])*3600;
    }
    elsif ($str eq "now")
    {
        return time();
    }
    elsif ($str eq "last_hour")
    {
        return time() - 3600;
    }
    elsif ($str eq "last_12hours")
    {
        return time() - 43200;
    }
    elsif ($str eq "last_day")
    {
        return time() - 86400;
    }
    elsif ($str eq "last_7days" || $str eq "last_week")
    {
        return time() - 604800;
    }
    elsif ($str eq "last_30days")
    {
        return time() - 2592000;
    }
    elsif ($str eq "last_180days")
    {
        return time() - 15552000;
    }

    # try ISO8601

    my $t = interval ($str);
    return time() - $t if defined $t;

    # YYYYMMDDZHHMM
    @t = $str =~ m!(\d{4})(\d{2})(\d{2})Z(\d{2})(\d{2})(\d{2})?!;
    if (exists $t[0])
    {
        $t[5] = 0 if not defined $t[5];
        return &gmmktime($t[5], $t[4], $t[3], $t[2], $t[1]-1, $t[0] - 1900);
    }

    # YYYY-MM-DD[_hh:mm:ss]
    @t = $str =~ m!(\d{4})-(\d{2})-(\d{2})([\s_](\d{2}):(\d{2}):(\d{2}))?!;
    # if it failed to parse the time string, just return undef
    if (not exists $t[0])
    {
        return $default;
    }

    if (not $t[3]) # no time information, assume 00:00:00
    {
        $t[4] = 0;
        $t[5] = 0;
        $t[6] = 0;
    }
    return &gmmktime($t[6], $t[5], $t[4], $t[2], $t[1]-1, $t[0]-1900);
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

# interval -- parse and convert ISO8601 interval to seconds
#
# P[nY][nM][nD][T[nH][nM][nS]]
#
# P -- required prefix -- for period
# Y -- year -- 365 days
# M -- month -- 30 days
# D -- days
# T -- optional time separator
# H -- hours
# M -- minutes
# S -- seconds

sub interval
{
    my $s = shift;
    my @t = $s =~ m!^P((\d+)Y)?((\d+)M)?((\d+)D)?(T((\d+)H)?((\d+)M)?((\d+)S)?)?!;

    if (!@t)
    {
        return undef;
    }

    # make the code more readable
    my $year = $t[1]?$t[1]:0;
    my $month = $t[3]?$t[3]:0;
    my $day = $t[5]?$t[5]:0;
    my $hour = $t[8]?$t[8]:0;
    my $minute = $t[10]?$t[10]:0;
    my $second = $t[12]?$t[12]:0;

    my $t = ($year * 365 + $month * 30 + $day) * 3600 * 24 + ($hour * 60 + $minute) * 60 + $second;

    return $t;
}

1;
