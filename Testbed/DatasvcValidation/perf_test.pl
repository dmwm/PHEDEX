#!/usr/bin/env perl

use IO::Socket::INET;
use IO::File;
use Sys::Hostname;
use Data::Dumper;
use Getopt::Long;

my $hostname = hostname();
my $port = 12345;
my $test_count = 10;
my $verbose = 1;
my $debug = 0;
my $web_server = "cmswttest.cern.ch";
my $test_url = 'transferqueueblocks?from=[FROM]&to=[TO]';
my $data_type;
my $help = 0;
my $test_host_file;

# default test hosts
# this could be over written by --test-host-file
my @test_host = (
	"lxplus221",
	"lxplus222",
	"lxplus223",
	"lxplus224",
	"lxplus225",
	"lxplus226",
	"lxplus227",
	"lxplus228");

GetOptions(
	"verbose!" => \$verbose,
	"webserver=s" => \$web_server,
	"count=i" => \$test_count,
	"debug!" => \$debug,
	"port=i" => \$port,
	"cmd=s" => \$test_url,
	"data-type=s" => \$data_type,
	"test-host-file=s" => \$test_host_file,
	"help" => \$help,
);

if ($help)	# only needs help
{
	usage();
	exit;
}

sub usage
{
	die <<EOF;

usage: $0 <options>

where <options> are:

--help                  show this infromation
--verbose               verbose mode, this is default
--noverbose             only show summary of the result
--debug                 more verbose than verbose mode
--webserver <web_host>  host name with optional port such as
                        "cmswttest.cern.ch:7001"
                        default is "cmswttest.cern.ch"
--data-type             how to interpreter positional @ARGV
                        it could be "node" or "link"
                        when being "node", positional @ARGV are
                        interpretered as list of nodes
                        when being "link", positional @ARGV are
                        interpretered as list of pairs of links
--test-host-file <file> the file that contains a list of test hosts
                        one host per line
--count                 number of test instances at the same time
--cmd                   test command, such as "agent?node=T1_US_FNAL_MSS"
--port                  port to communicate with test hosts
                        default is 12345
EOF
}

sub trim
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

if ($test_host_file)
{
	open (INF, $test_host_file) || die "no such file '$test_host_file'";
	@test_host = ();
	while (<INF>)
	{
		if ($_ && (substr($_, 0, 1) ne "#"))
		{
			push @test_host, trim($_);
		}
	}
	close (INF);
}

if ($debug)
{
	print "test_hosts\n";
	print Dumper(\@test_host);
}

my $sock = IO::Socket::INET->new(
        Listen    => $test_count,
        LocalAddr => $hostname,
        LocalPort => $port,
        Proto     => 'tcp');

my $url_prefix = "http://$web_server/phedex/datasvc/xml/prod/";

sub get_nodes
{
	# my $url = $url_prefix."nodes";
	my $url = "http://$web_server/phedex/datasvc/perl/prod/nodes";

	open fh, "wget -O - \"$url\" 2>/dev/null 1| ";

	my $s;

	while (<fh>)
	{
		$s .= $_;
	}

	close fh;

	my $phedex = eval $s;

	my @hosts;

	foreach (@{$phedex->{PHEDEX}{NODE}})
	{
		push @hosts, $_->{NAME};
	}
	return @hosts;
}

sub get_links
{
	# my $url = $url_prefix."transferhistory\?starttime=last_7days";
	my $url = "http://$web_server/phedex/datasvc/perl/prod/transferhistory\?starttime=last_7days";

	open fh, "wget -O - \"$url\" 2>/dev/null 1| ";

	my $s;

	while (<fh>)
	{
		$s .= $_;
	}

	close fh;

	my $phedex = eval $s;
	my @links;

	foreach (@{$phedex->{PHEDEX}{LINK}})
	{
		push @links, {FROM => $_->{FROM}, TO => $_->{TO}};
	}
	return @links;
}

my @nodes;

if ($data_type eq "node")
{
	@nodes = @ARGV;
}
else
{
	@nodes = sort(get_nodes());
}
my $nodep = 0;

my @links;

if ($data_type eq "link")
{
	while (scalar @ARGV)
	{
		push @links, {"FROM" => shift @ARGV, "TO" => shift @ARGV};
	}
}
else
{
	@links = get_links();
}
my $linkp = 0;

if ($debug)
{
	print "hostname = ", $hostname, "\n";
	print "port = ", $port, "\n";
	print "test_count = ", $test_count, "\n";
	print "verbose = ", $verbose, "\n";
	print "debug = ", $debug, "\n";
	print "web_server = ", $web_server, "\n";
	print "test_url = ", $test_url, "\n";
	print Dumper(\@nodes);
	print $#nodes+1, " nodes\n";
	print Dumper(\@links);
	print $#links+1, " links\n";
}

sub getanode
{
	my $i = $nodep;
	$nodep = ($nodep + 1) % ($#nodes + 1);
	return $nodes[$i];
}

sub getalink
{
	my $i = $linkp;
	$linkp = ($linkp + 1) % ($#links +1);
	return $links[$i];
}

my $wait = (int($test_count/20)+1 )*5;

if ($debug)
{
	print "wait = ", $wait, "\n";
}

my $start = time() + $wait;

my @cmds;

# redirect stderr
open STDERR, ">/dev/null";

# launching the test
for (my $i = 0; $i < $test_count; $i++)
{
	# my $ii = $i % ($#node + 1);
	# my $cmd = "ptest.pl $hostname $port $start $i $url_prefix/agents\\\\?node=$node[$ii]";
	# my $url = $url_prefix.'/transferqueueblocks?from='.$node[$ii];
	my $url = $test_url;
	if ($url =~ m/\[NODE\]/)
	{
		my $node = getanode();
		$url =~ s/\[NODE\]/$node/;
	}

	if (($url =~ m/\[FROM\]/) || ($url =~ m/\[TO\]/))
	{
		my $link = getalink();
		$url =~ s/\[FROM\]/$link->{FROM}/;
		$url =~ s/\[TO\]/$link->{TO}/;
	}

	if (index($url, "?") == -1)
	{
		$url = $url_prefix.$url."?nocache=1";
	}
	else
	{
		$url = $url_prefix.$url."&nocache=1";
	}
        $cmds[$i] = $url;
	$url =~ s/\?/\\\?/g;
	$url =~ s/\&/\\\&/g;

	my $cmd = "ptest.pl $start $i '$url' $hostname $port";
	my $t_node = $test_host[$i % $#test_host];
	$cmd = "ssh -x $t_node ".$cmd;

	if ($debug)
	{
		print $cmd, "\n";
	}

	system("$cmd &");
}

my $min_call_t = 100000;
my $max_call_t = 0;
my $total_call_t = 0;

my $min_c_t = 100000;
my $max_c_t = 0;
my $total_c_t = 0;

my %result;

my $answer = 0;
while(my $client = $sock->accept()) {
        while(<$client>) {
                %result = unpack("(w/a*)*", $_);
		if ($result{status} eq "OK")
		{
			if ($verbose)
			{
				printf "%4d %20s %6d %6s %s %10.6f %10.6f %10.6f %s %s %s\n",
					$result{id},
					$result{test_host},
					$result{pid},
					$result{status},
					$result{request_date},
					$result{call_time},
					$result{ctime},
					$result{ctime} - $result{call_time},
					$result{load},
					$result{request_url},
					$cmds[$result{id}];
			}

			if ($result{call_time} > $max_call_t)
			{
				$max_call_t = $result{call_time};
			}

			if ($result{call_time} < $min_call_t)
			{
				$min_call_t = $result{call_time};
			}

			$total_call_t += $result{call_time};

			if ($result{ctime} > $max_c_t)
			{
				$max_c_t = $result{ctime};
			}

			if ($result{ctime} < $min_c_t)
			{
				$min_c_t = $result{ctime};
			}

			$total_c_t += $result{ctime};

		}
		else
		{
			printf "%4d %32s %6d %6s %s\n",
				$result{id},
				$result{test_host},
				$result{pid},
				$result{status},
				$result{message};
		}

        }
	$answer++;
	if ($answer >= $test_count)
	{
		if ($verbose)
		{
			printf "\n%d tests\n", $test_count;
			printf "Average        call time: %10.6f (%10.6f .. %10.6f)\n", $total_call_t / $test_count, $min_call_t, $max_call_t;
			printf "Average turn-around time: %10.6f (%10.6f .. %10.6f)\n", $total_c_t / $test_count, $min_c_t, $max_c_t;
		}
		else
		{
			printf "Summary: %3d %10.6f %10.6f %10.6f %10.6f\n", $test_count,  $total_call_t / $test_count, $total_c_t / $test_count, $max_call_t, $max_c_t;
		}
		exit;
	}
}

