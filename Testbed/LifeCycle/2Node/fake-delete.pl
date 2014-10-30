#!/usr/bin/env perl

# Randomly tests each of the possible validation outcomes

use warnings;
use strict;

my ($stage, $pfn) = @ARGV;

my $r = rand();

if ($stage eq 'pre') {
    print "pre-deletion test:   pfn=$pfn\n";
} elsif ($stage eq 'post') {
    print "post-deletion test:  pfn=$pfn\n";
} else {
    print "unknown stage=$stage!\n";
}

exit(0);
