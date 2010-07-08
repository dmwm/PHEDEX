#!/usr/bin/env perl

# Randomly tests each of the possible validation outcomes

use warnings;
use strict;

my ($status, $pfn, $size, $checksum) = @ARGV;

my $r = rand();

if ($status eq 'pre') {
    print "pre-validation test\n";
    if ($r < .1) {
	print "fake validation success\n";
	exit(0);
    } elsif ($r < .2) {
	print "fake validation veto\n";
	exit(1);
    } else {
	print "fake validation failure\n";
	exit(2);
    }
} else {
    print "post-validation test\n";
    if ($r < .1) {
	print "post-validation failure\n";
	exit(1);
    } else {
	print "post-validation success\n";
	exit(0);
    }
}
