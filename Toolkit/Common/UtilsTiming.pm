# Timing utilities.  First define higher-resolution timing via
# gettimeofday() where it is available, otherwise fall back on
# time().
use vars qw(@startTime);
BEGIN {
  # missing virtually everywhere, but it's worth trying anyway
  eval "use Time::HiRes 'gettimeofday'";
  if (! $@) {
    eval 'sub mytimeofday { my (@t) = &gettimeofday();
      return $t[0] + $t[1] / 1_000_000.0; }';
  } else {
    eval { require 'sys/sycall.ph'; };
    if (! defined (&SYS_gettimeofday) && $^O =~ /linux/) {
      require 'asm/unistd.ph';
      if (defined (&__NR_gettimeofday)) {
        eval 'sub SYS_gettimeofday { &__NR_gettimeofday; }';
      }
    }
    if (defined (&SYS_gettimeofday)) {
      eval 'sub mytimeofday {
        my $t = pack("LL", ());
        syscall (&SYS_gettimeofday, $t, 0) != -1 or die "gettimeofday: $!";
        my @tv = unpack ("LL", $t);
	return $tv[0] + $tv[1]/1_000_000.0;
      }';
    } else {
      eval 'sub mytimeofday { return time(); }';
    }
  }
}

sub timeStart
{
    my ($array) = @_;
    ($array ? @$array : @startTime) = (&mytimeofday, times);
}

sub elapsedTime 
{
    my ($start) = @_;
    my @now = (&mytimeofday, times);
    my @old = ($start ? @$start : @startTime);
    return ($now [0] - $old [0], $now[3] - $old [3], $now[4] - $old [4]);
}

sub formatElapsedTime
{
    return sprintf ("%.2fr %.2fu %.2fs", &elapsedTime(@_));
}

1;
