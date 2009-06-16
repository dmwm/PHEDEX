#!/usr/bin/env perl

# ptest.pl -- test driver for perf_test.pl
#
# this is to be installed on each test host and should be in default
# command path
#
# the ideal environment is to have all test hosts share a file system
# that has ptest.pl installed

use IO::Socket::INET;
use IO::File;
use XML::Simple;
use Data::Dumper;
use Sys::Hostname;
use Time::HiRes qw ( clock_gettime );	# use high resolution timer

my ($start, $test_id, $url, $remote_host, $remote_port) = @ARGV;

# just for debugging in development
#
# print "remote_host = ", $remote_host, "\n";
# print "remote_port = ", $remote_port, "\n";
# print "      start = ", $start, "\n";
# print "    test_id = ", $test_id, "\n";
# print "   test_cmd = ", $test_cmd, "\n";

my $xml = new XML::Simple;

# wait for start
while (time() < $start)
{
	sleep 1;
}

my %result = (
	id => $test_id,
	test_host => hostname(),
	pid => $$ );

# execute the command
my $t0 = clock_gettime();
my $fh = IO::File->new("wget -O - \"$url\" 2>/dev/null 1| ");

my $data = $xml->XMLin($fh);

$result{"ctime"}= clock_gettime() - $t0;

if (ref($data) ne "HASH")
{
	$result{"status"} = "ERROR";
	$result{"mesage"} = $data;
}
else
{
	$result{"status"} = "OK";
	$result{"message"} = "";
	$result{"request_url"} = $data->{"request_url"};
	$result{"request_date"} = $data->{"request_date"};
	$result{"call_time"} = $data->{"call_time"};
	open (f1, "/proc/loadavg");
        $result{"load"} = (split(" ", <f1>))[0];
	close f1;
}

# was it invoked remotely?

if ($remote_host)
{
	my $res = pack("(w/a*)*", %result);
	my $sock = new IO::Socket::INET (
		PeerAddr => $remote_host, 
		PeerPort => $remote_port,
		Proto => 'tcp' );
	die "Could not create socket ($remote_host:$remote_port): $!\n" unless $sock;

	print$sock $res;
}
else # print it to screen
{
	printf "%4d %20s %6d %6s %s %10.6f %10.6f %10.6f %s %s\n",
		$result{id},
		$result{test_host},
		$result{pid},
		$result{status},
		$result{request_date},
		$result{call_time},
		$result{ctime},
		$result{ctime} - $result{call_time},
		$result{load},
		$result{request_url};
}
