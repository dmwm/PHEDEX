#!/usr/bin/env perl

use XML::Simple;
use IO::File;
use Getopt::Long;

my $web_server = "cmswttest.cern.ch";
my $url_prefix = "http://$web_server/phedex/datasvc/xml/prod";
my $xml = new XML::Simple;

my $debug = 0;
my $verbose = 0;
my $test_file;
my $help;

GetOptions(
	"verbose!" => \$verbose,
	"webserver=s" => \$web_server,
	"debug!" => \$debug,
	"file=s" => \$test_file,
	"help" => \$help,
);

sub usage()
{
	die <<EOF;

Usage: $0 [--verbose] [--webserver <web_host>] [--debug] [--file <test_file>]

--verbose               verbose mode
--help                  show this information
--webserver <web_host>  host name with optional port number such as
                        "cmswttest.cern.ch:7001"
                        default to be: "cmswttest.cern.ch"
--file <file>           file that contains test command
                        without --file, the commands are read from stdin
EOF
}

if ($help)
{
	usage();
}

open STDERR, ">/dev/null";

sub verify
{
	my ($url, $expect) = @_;
	my $result = "OK   ";
	if (! defined $expect)
	{
		$expect = "OK   ";
	}

	if (substr($url, 0, 1) eq "-")
	{
		$expect = "ERROR";
		$url = substr($url, 1);
	}

	my $t0 = time();
	my $fh = IO::File->new("wget -O - '$url' 2>/dev/null 1| ");
	my $data = $xml->XMLin($fh);
	if (ref($data) ne "HASH")
	{
		$result = "ERROR";
	}
	else
	{
		$result = "OK   ";
	}
	my $res = ($result eq $expect)?"PASS ":"FAIL ";
	print $res, "(", $expect, " ", $result, ") ", time() - $t0, " ",$url, "\n";
}

my $inf;

if ($test_file)
{
	open $inf, $test_file;
}
else
{
	$inf = scalar STDIN;
}

while(<$inf>)
{
	chomp;
	my $c1 = substr($_, 0, 1);
	if ($c1 eq "#")
	{
		print $_, "\n";
	}
	elsif ($c1 eq "-")
	{
		verify("$url_prefix/".substr($_, 1), "ERROR");
	}
	elsif (length($_) > 1)
	{
		verify("$url_prefix/$_", "OK   ");
	}
}

