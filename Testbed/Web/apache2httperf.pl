#!/usr/bin/perl

# Make an URL replay file for use with httperf. Taking an apache log
# file as input, it outputs a ASCII-null (\0) separated list of URL
# paths requested. Requests are sorted in time order. Accepts a
# '--filter' argument to filter the input logs by a regular
# expression.


use warnings;
use strict;

use Getopt::Long;
use POSIX qw(mktime);
use Time::HiRes;
$|++;

my %args = ();

GetOptions(
    'filter|f=s' => \$args{filter},
    ) || die $!;

my $time_re   = qr:\[([^ ]+).*\]:;
my $access_re = qr/"GET (.*) HTTP.*"/;
my $filter_re = qr/$args{filter}/ if $args{filter};
our %dates;

my @replay;
while (<>) {
    next unless $_ =~ $access_re;
    my $url = $1;
    next unless $_ =~ $time_re;
    my $time = $1;
    my $ts = &make_time($time);
    next if $filter_re && $url !~ $filter_re;

    push @replay, { TIME => $ts, DATE => $time, URL => $url };
}

@replay = sort { $a->{TIME} <=> $b->{TIME} } @replay;
my $duration = ($replay[$#replay]->{TIME} - $replay[0]->{TIME});

foreach my $r (@replay) {
    print "$$r{URL}\0";
}

# Note, not an absolute timestamp; doesn't consider DST, GMT, etc.
sub make_time
{
    my $time = shift;
    my ($date, $h, $m, $s) = split(/:/, $time);
    my ($D, $Mon, $Y) = split(/\//, $date);
    my $M = $dates{$Mon};
    return &POSIX::mktime($s, $m, $h, $D, $M, $Y - 1900);
}

sub BEGIN
{
    my $i = 0;
    foreach (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)) {
	$dates{$_} = $i++;
    }
}
