#!/usr/bin/perl

# Analyze apache logs to determine the usage of the Graph server.
# For each graph-type, link/node grouping, and whether the nodes were
# filtered, prints the number of requests along and the percent of the
# total number of requests

use warnings;
use strict;

my %stats;
my $total;
while (<>) {
    next unless $_ =~ m:/phedex/graphs/([^?]+)?.*link=([^&; ]+):;
    my $graph = $1;
    my $link  = $2;
    my ($from) = ( $_ =~ m:from_node=([^&; ]+): );
    my ($to) =   ( $_ =~ m:to_node=([^&; ]+): );

    my $nodes = 'all';
    if ( ($from && $from ne '.*') || ($to && $to ne '.*') ) {
	$nodes = 'filtered';
    }
    $stats{"$graph:$link:$nodes"}++;
    $total++;
}

print "graph:link:nodes percent\n", '='x40, "\n";
print map { sprintf("%-35s %0.2f%%\n", $_, ($stats{$_}/$total)*100) } sort keys %stats;
