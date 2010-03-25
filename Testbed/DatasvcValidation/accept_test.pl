#!/usr/bin/env perl
use warnings;
use strict;

use Time::HiRes qw(gettimeofday tv_interval);
use POSIX;
use XML::Simple;
use IO::File;
use Getopt::Long;
use JSON::XS;
use Data::Dumper;

my $web_server = "cmswttest.cern.ch";
my $url_path   = "/phedex/datasvc";
my $url_instance = "/prod";
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
    # my ($url, $expect) = @_;
    my ($url_prefix, $format, $call, $expect, $key, $count) = @_;
    die "verify():  url_prefix, format, call and expect are required\n" unless $url_prefix && $expect && $format && $call;
        my $url = "${url_prefix}/${format}${url_instance}/$call";
    print "verifying '$url', expecting $expect\n" if $debug;

    my $result = "OK";

    my $tee = $output_dir ? sprintf("tee $output_dir/%03s.${$format}|", $n) : '';
    my $t0 = [gettimeofday];
    my $data;
    my $VAR1 = undef;
    if ($format eq 'xml')
    {
        my $fh = IO::File->new("wget -O - '${url}' 2>/dev/null 1|${tee} ")
            or die "could not execute wget\n";
        $data = $xml->XMLin($fh, ForceArray=>1);
    }
    elsif ($format eq 'perl')
    {
        open FILE, "wget -O - '${url}' 2>/dev/null 1|${tee} "
            or die "could not execute wget\n";
        my $sep = $/;    # save input separator
        undef $/;    # read everything in one shot
        eval (<FILE>);
        $/ = $sep;    # restore input separator
        close FILE;
        $data = $VAR1->{PHEDEX};
    }
    elsif ($format eq 'json')
    {
        open FILE, "wget -O - '${url}' 2>/dev/null 1|${tee} ";
        $data = decode_json(<FILE>)->{phedex};
    }
    else #ERROR
    {
        printf "ERROR: unknown format $format\n";
        $n++;
        return;
    }

    my $call_time = 0;
    my $len;
    if (ref($data) ne "HASH")
    {
        $result = "ERROR";
    }
    else
    {
        if ($key)
        {
            my $list;
            if ($format eq "perl")
            {
                $key = uc $key;
            }
            else
            {
                $key = lc $key;
            }
            $list = $data->{$key};
            if (ref($list) eq "HASH")
            {
                $len = keys %{$list};
            }
            elsif (ref($list) eq "ARRAY")
            {
                $len = @{$list};
            }
            else
            {
		if ($format eq 'xml')
                {
                    $len = 0;
                }
                else
                {
                    $len = undef;
                }
            }

            # deal with count
            if ($count)
            {
                my $val;
                my $c1 = substr($count, 0, 1);
                my $c2 = substr($count, 0, 2);
                $val = (($c2 eq '>=') || ($c2 eq '<='))?int(substr($count, 2)):int(substr($count, 1));
                if ($c2 eq '>=')
                {
                    $result = ($len >= $val)?'OK':'CTERR';
                }
                elsif ($c2 eq '<=')
                {
                    $result = ($len <= $val)?'OK':'CTERR';
                }
                elsif ($c1 eq '>')
                {
                    $result = ($len >  $val)?'OK':'CTERR';
                }
                elsif ($c1 eq '<')
                {
                    $result = ($len <  $val)?'OK':'CTERR';
                }
                elsif ($c1 eq '=')
                {
                    $result = ($len ==  $val)?'OK':'CTERR';
                }
            }
        }

        if ($format eq "perl")
        {
            $call_time = $data->{CALL_TIME};
        }
        else
        {
            $call_time = $data->{call_time};
        }
    }
    my $elapsed = tv_interval ( $t0, [gettimeofday]);
    # presentation of $len/count
    if (! defined $len)
    {
        $len = " N/A ";
    }
    else
    {
        $len = sprintf("%05i", $len);
    }
    my $res = ($result eq $expect)?"PASS":"FAIL";
    printf "%03i %4s (%5s %5s) call=%0.4f total=%.4f count=$len %s\n", $n, $res, $expect, $result, $call_time, $elapsed, $url;
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

print "# ", &POSIX::strftime("[%Y-%m-%d %T]", gmtime), ": acceptance test of $url_prefix\n";

while(<$inf>)
{
    chomp;
    next if /^\s*$/;
    my ($call, $key, $count) = split();
    my $c1 = substr($call, 0, 1);
    my $expect = "OK";

    if ($c1 eq "#")
    {
        # double ## is for internal use
        if (substr($call, 1, 1) ne '#')
        {
            print $_, "\n";
        }
        next;
    }

    if ($c1 eq "-")
    {
            $expect = "ERROR";
            $call = substr($call, 1);
    }
    #verify("$root_url/$call", $expect);
    verify("${url_prefix}${url_path}", "xml", $call, $expect, $key, $count);
    verify("${url_prefix}${url_path}", "perl", $call, $expect, $key, $count);
    verify("${url_prefix}${url_path}", "json", $call, $expect, $key, $count);
}
