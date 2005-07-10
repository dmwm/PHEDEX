#! /usr/bin/perl -w

# lemon-query.pl
# 
# Usage: ./lemon-query [OPTION]
#     -n    --nodes       list of nodes to sample - ranging supported
#     -m    --metrics     list of metrics to sample - ranging supported
#     -e    --end         the upper timestamp limit  
#     -p    --period      the period of sampling
#     -d    --dns         activate node dns check
#     -t    --timestring  show timestringing
#
# Notes:
#     i)   EDG_LOCATION and MR_SERVER_URL should be set appropriately refer to lemon webpages
#     ii)  --end and --period are optional, if unspecified the latest value will be returned
#     iii) nodes and metrics support ranging, refer to examples
#
# Examples
#
#     i)   --nodes "lxb0001 lxb0002" --metrics "10002 10004"
#          extract the latest value for metric 10002 and 10004 for nodes lxb0001 and lxb0002
#     
#     ii)  --nodes "lxb[0001-1000]" -- metrics "10001-10010"
#          extract the latest value for metric 10001 through 10010 for nodes lxb0001 through lxb1000
#
#     iii) --nodes "lxb[0,2]30[3-5,7]" --metrics "10001" --timestring --dns
#          extract the latest value for metric 10001 for nodes lxb0303 lxb0304 lxb0305 lxb0307 lxb2303
#          lxb2304 lxb2305 lxb2307 check each node for an entry in dns and display results showing the
#          results using a formatted time string as opposed to timestamp in seconds
#
#     iv)  --nodes "lxb[0,2]30[3-5,7]" --metrics "1000" --timestring --dns --end 1 --period 2
#          same as above but instead of latest sample it collects results for a period of two days with
#          the upper timestamp limit equal to x days ago
#
# See Also:
#     http://lemon.web.cern.ch/lemon
#     http://lemon.web.cern.ch/lemon/cern/lemon_at_cern.html
#
# Thanks to:
#     Sylvain Chapeland                                            - Lemon MRs_API
#     Claudia Bondila (original author) & David Huges (maintainer) - Wassh
#
# Author: Dennis Waldron (dennis.waldron@cern.ch)

use strict;
use warnings;
use diagnostics;

use Getopt::Long qw(:config no_permute bundling);
use English;

use lib '/opt/edg/lib';
use fmonMRs;

$ENV{'EDG_LOCATION'} ||= '/opt/edg';

die "MR Server URL must be defined in MR_SERVER_URL" unless exists $ENV{'MR_SERVER_URL'};


# constants

use constant DAY_INTERVAL => 86400;

#
# prototypes
#

sub expand_node_range($);
sub recurse_node_range($);
sub expand_number_set($);
sub main();

# regular expressions for node expansion

my $word_RE         = '[-\w]+';
my $number_range_RE = '\d+(-\d+)?';
my $number_set_RE   = "$number_range_RE(,$number_range_RE)*";
my $host_range_RE   = "($word_RE|\\[$number_set_RE\\])+";

# getoptions
		      
my %options;

# methods

&main();

#
# main
#

sub main() {

	# local lexicals
	my ($qnodes, $qmetrics, $qstart, $qend) = (undef, undef, -1, -1);
	my ($qstart_str, $qend_str) = ('','');

	my $node;
	my $metric;
	my $timestamp;
	my $value;
	my $rid;

	my ($buf, $cnt, %samples) = (undef, 0);

	
	# process options
	if (!GetOptions(\%options, 'n|nodes=s', 'm|metrics=s', 'd|dns', 'p|period=i', 'e|end=i', 't|timestring')) {
		exit(-1);
	}
	
	# process nodes
	if ($buf = $options{n}) {
		if ($buf =~ /\[|,/) {
			$qnodes   = join(" ", expand_node_range($buf));
		} else {
			$qnodes   = $buf;
		}
	} 

	# process metrics
	if ($buf = $options{m}) {
		if ($buf =~ /-/) {
			$qmetrics = join(" ", expand_number_set($buf));
		} else {
			$qmetrics = $buf;
		}
	}

	# metrics and nodes exist ?
	if (!$qmetrics || !$qnodes) {
		printf STDERR "unable to make query - no nodes or metrics to sample\n";
		exit(-1);
	}


	# process timestamps
	if ($buf = $options{e}) {
		
		$qend       = time() - ($buf * DAY_INTERVAL);
		$qend_str   = localtime($qend);

		if (!$options{p}) {
			printf STDERR ("no --period option specified for historical sampling\n");
			exit(-1);
		} elsif ($options{p} < 0) {
			printf STDERR ("Value \"%d\" invalid for option period (positive integer expected)\n", $options{p});
			exit(-1);
		}
		
		$qstart     = ($qend - ($options{p} * DAY_INTERVAL));
		$qstart_str = localtime($qstart);
			     
	} 


	# summary
	printf("Retrieving samples from Monitoring Repository '%s'\n\tnodes:\t\t %s\n\tmetrics:\t %s\n\tlower timestamp: %s - (%ld)\n\tupper timestamp: %s - (%ld)\n\n", 
	       $ENV{MR_SERVER_URL}, $qnodes, $qmetrics, $qstart_str, $qstart, $qend_str, $qend);


	# open interface
	if (fmonMRs::MRs_open() == -1) {
		printf STDERR ("MRs_open() failed - %s\n", fmonMRs::MRs_getError());
		exit(-1);
	}


	# query
	$rid = fmonMRs::MRs_getSamples($qnodes, $qmetrics, $qstart, $qend);
	if ($rid == -1) {
		printf STDERR ("MRs_getSamples() failed - %s\n", fmonMRs::MRs_getError());  
	} else {
		while (fmonMRs::MRs_getNextSampleFromQuery($rid, \$node, \$metric, \$timestamp, \$value) == 0) {
			
			$value =~ s/^\s+//;
			$value =~ s/\s+$//;

			$samples{$node}{$metric}{$timestamp} = $value;
		}	}	

	# output results
	foreach $node (sort keys (%samples)) {
		foreach $metric (sort keys ( %{ $samples{$node} } )) {
			foreach $timestamp (sort keys ( %{ $samples{$node}{$metric} } )) {

				$buf = $samples{$node}{$metric}{$timestamp};
				if ($options{t}) {
					$timestamp = localtime($timestamp);
				}

				printf("\t%s\t%ld\t%s\t%s\n", $node, $metric, $timestamp,$buf);

				$cnt++;
			}
		}
		printf("\n");
	}


	# result message
	printf("Total: %d result%s\n\n", $cnt, $cnt != 1 ? 's' : '');

	# close interface
	if (fmonMRs::MRs_close() == -1) {
		printf STDERR ("MRs_close() failed - %s\n", fmonMRs::MRs_getError());
	}

	exit(1);
}


# 
# expand_node_range
#
# Input example: cms[0,2]3[3-5,7]b
# Ouptut:        cms003b cms034b cms035b cms037b cms233b cms234b cms235b cms237b
#

sub expand_node_range($) {

	# local lexicals
	my ($node_range) = @_;
	my (%seen, @nodes, $node);
	
	foreach $node (recurse_node_range($node_range)) {
		if (!exists($seen{$node})) {
			push(@nodes, $node);
		}
		$seen{$node} = 1;
	}

	if ($options{d}) {
		@nodes = grep { gethostbyname($_) } @nodes; 
	}

	if (!@nodes) {
		if ($options{d}) {
			printf STDERR ($node_range =~ /\[/
				       ? "'$node_range' contains no nodes in the DNS\n"
				       : "no such node '$node_range'\n");
		} else {
			printf STDERR ("no such node '$node_range'\n");
		}
		exit(-1);
	}

	
	return @nodes;
}


#
# recurse_node_range
#

sub recurse_node_range($) {
	
	# local lexicals
	my ($node_range) = @_;
	my (@heads, @tails, $head, $tail, $range_tail);
	
	my @output;

	if ($node_range eq '') {
		return ('');
	} elsif ($node_range =~ /^($word_RE)/o) {
		@heads = ($1);
		$range_tail = $POSTMATCH;
	} elsif ($node_range =~ /^\[($number_set_RE)\]/o) {
		@heads = expand_number_set($1);
		$range_tail = $POSTMATCH;
	} else {
		die ("unable to process '$range_tail' in recurse_node_range");
	}
	@tails = recurse_node_range($range_tail);

	foreach $head (@heads) {
		foreach $tail (@tails) {
			push(@output, "$head$tail");
		}
	}

	return @output;
}


#
# expand_number_set
#
# Input example: 023,048-147,250
# Output:        023 048 049 050 ... 147 250
# Exceptions:    differing length digit sequence, "a-b" where a > b.

sub expand_number_set($) {

	# local lexicals
	my ($number_set) = @_;
	my (@output, @len, $len, $range, $lo, $hi);

	# check for length constraint
	@len = map {length $_} ($number_set =~ /\d+/g);
	$len = $len[0];

	if (grep {$_ != $len} @len) {
		die ("differing-length numbers in '$number_set'");
	}

	foreach my $range (split /,/, $number_set) {
		my ($lo,$hi) = (split /-/, $range);
		
		if (!defined($hi)) {
			$hi = $lo;
		}
		if ($lo > $hi) {
			die ("first number excess second in '$range'\n");
		}
		push(@output, map {sprintf "%0${len}d", $_} ($lo..$hi));
	}

	return @output;
}


# End-of-File
