#!/usr/bin/perl

# Script to analyze apache log files.  Goal is to help find which
# client is creating the most lost: Prints:
# - For each client host and hour, a break down of the number of
#   requests per HTTP response code
# - A summary of the number of requests for each hour, and the percent
#   of the total
# - The total number of requests input, and the average requests per hour

use warnings;
use strict;

# ::ffff:128.142.218.141 - - [08/Dec/2009:10:18:03] "GET /phedex/graphs/quality_all?link=src&title=&no_mss=true&from_node=.*&to_node=T1_IT_CNAF&width=389&height=292&text_size=10&starttime=1260007200.455&span=3600&endtime=1260266400.455&conn=Prod%2FWebSite HTTP/1.1" 200 16133 "" ""

my $data = {};
my $stats = {};
while (<>) {
    next unless $_ =~ m:/phedex/graphs:;

    my ($ip, $date, $time, $hour, $req, $status, $size);
    if (/^(\S+) (\S+(, \S+)?) \S+ \S+ \[(..\/...\/....):((..):..:..) \S+\] "(.+)" (\d+) (.+)/) {
	$ip = $2;
	$date = $4;
	$time = $5;
	$hour = $6;
	$req = $7;
	$status = $8;
	$size = $9;
    } else {
	print "skip $_";
	next;
    }

    # print "ip=$ip date=$date time=$time hour=$hour status=$status\n";
    $data->{$ip}->{$date}->{$hour}->{$status}++;
    $stats->{"$date:$hour"}++;
}

foreach my $ip ( sort keys %$data ) {
    foreach my $date ( sort keys %{ $data->{$ip} } ) {
	foreach my $hour ( sort keys %{ $data->{$ip}->{$date} } ) {
	    my $hourbin = $data->{$ip}->{$date}->{$hour};
	    print "$ip $date $hour ",
	    join (', ', map { "$_=$hourbin->{$_}" } sort keys %$hourbin), "\n";
	}
    }
}

my $sum = 0; $sum += $_ foreach values %$stats;
my $avg = $sum / scalar values %$stats;

print "\nStats:\n";
printf "%-20s%i (%0.2f%%)\n", $_, $stats->{$_}, ($stats->{$_}/$sum)*100 foreach sort keys %$stats;
printf "%-20s%i\n", 'total requests:', $sum;
printf "%-20s%i\n", 'avg per hour:', $avg;
