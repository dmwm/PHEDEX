#!/usr/bin/env perl
use warnings;
use strict;

use Time::HiRes qw(gettimeofday tv_interval);
use XML::Simple;
use IO::File;
use Getopt::Long;

my $web_server = "cmswttest.cern.ch";
my $url_path   = "/phedex/datasvc";
my $url_data   = "/xml/prod";
my $xml = new XML::Simple;

my $debug = 0;
my $verbose = 0;
my $test_file;
my $output_dir;
my $help;

GetOptions(
	"verbose!" => \$verbose,
	"webserver=s" => \$web_server,
        "path=s" => \$url_path,
	"debug!" => \$debug,
	"file=s" => \$test_file,
        "output|O=s" => \$output_dir,
	"help" => \$help,
);

sub usage()
{
	die <<EOF;

Usage: $0 [--verbose] [--debug] [--webserver <web_host>] [--path <path>] [--file <file>] [--output <dir>]

--verbose               verbose mode
--help                  show this information
--webserver <web_host>  host name with optional port number such as
                        "cmswttest.cern.ch:7001"
                        default: "cmswttest.cern.ch"
--path <path>           root path to the data service
                        default: "/phedex/datasvc"
--file <file>           file that contains test command
                        without --file, the commands are read from stdin
--ouptut <dir>          save data service output to files in this directory

EOF
}

if ($help)
{
	usage();
}

my $url_prefix = "http://$web_server";

open STDERR, ">/dev/null";
our $n = 0;
sub verify
{
	my ($url, $expect) = @_;
	die "verify():  $url and $expect required\n" unless $url && $expect;
	print "verifying '$url', expecting $expect\n" if $debug;

	my $result = "OK";

	my $tee = $output_dir ? sprintf("tee $output_dir/%03s.xml|", $n) : '';
	my $t0 = [gettimeofday];
	my $fh = IO::File->new("wget -O - '$url' 2>/dev/null 1|$tee ")
	    or die "could not execute wget\n";

	my $data = $xml->XMLin($fh);
	if (ref($data) ne "HASH")
	{
		$result = "ERROR";
	}
	else
	{
		$result = "OK";
	}
	my $elapsed = tv_interval ( $t0, [gettimeofday]);
	my $res = ($result eq $expect)?"PASS ":"FAIL ";
	printf "%03i %4s (%4s %4s) %.4f %s\n", $n, $res, $expect, $result, $elapsed, $url;
	$n++;
}

my $inf;

if ($test_file)
{
	open $inf, $test_file;
}
else
{
	$inf = scalar *STDIN;
}

my $root_url = "${url_prefix}${url_path}${url_data}";

while(<$inf>)
{
	chomp;
	next if /^\s*$/;
	my $call = $_;
	my $c1 = substr($call, 0, 1);
	my $expect = "OK";

	if ($c1 eq "#")
	{
		print $_, "\n";
		next;
	}
	elsif ($c1 eq "-")
	{
	        $expect = "ERROR";
	        $call = substr($call, 1);
	}

	verify("$root_url/$call", $expect);
}
