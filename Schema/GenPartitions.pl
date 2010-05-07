#!/usr/bin/perl

# Script to generate statements to add range partitions to a table in
# Oracle.  The syntax is: 
#
#   GenPartitions.pl TABLE FROM TO 
#
# Where FROM and TO are month timestamps in the format YYYY-MM The
# script is used to generate partitions of one month duration over the
# FROM, TO range (inclusive).  The output can be fed into sqlplus.

use warnings;
use strict;
use Time::Local qw(timegm);

my ($table, $from, $to) = @ARGV;

my ($from_year, $from_month) = split /-/, $from;
my ($to_year, $to_month) = split /-/, $to;

foreach ($from_year, $from_month, $to_year, $to_month) {
    die "invalid time!" unless $_ =~ qr/^\d+$/;
}
foreach ($from_month, $to_month) {
    die "invalid time!" unless ($_ >= 1 && $_ <= 12);
}

my $n_years = $to_year - $from_year;
my $n_months = $to_month - $from_month;
if ($n_months < 0) {
    $n_months += 12;
    $n_years--;
}
die "negative time!" if $n_years < 0;
$n_months += $n_years * 12;

print "-- creating partitions from $from to $to ($n_months months)\n";

my $month = $from_month;
my $year = $from_year;

for (0..$n_months) {
    my $label = sprintf '%04i-%02i', $year, $month;
    my $val = &timegm(0,0,0,1,$month-1,$year-1900);
    my $ddl = "alter table $table add partition \"$label\" values less than ($val)";
    print $ddl, ";\n";

    $month++;
    if ($month > 12) {
	$month = 1;
	$year++;
    }
}
