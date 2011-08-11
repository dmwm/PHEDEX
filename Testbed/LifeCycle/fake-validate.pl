#!/usr/bin/env perl

# Randomly tests each of the possible validation outcomes

use warnings;
use strict;

my ($status, $pfn, $size, $checksum) = @ARGV;

my $r = rand();

# Parse pfn to get dataset/block/file names as defined in Lifecycle.pm  

my @fields = reverse (split "/", $pfn);

my $filename = shift @fields;
my $blockname = shift @fields;
my $datasetname = shift @fields; 
my $threshold = 0;
print  "file: $filename\nblock: $blockname\ndataset: $datasetname\n";

($filename =~ /-stuckfile$/) && print "Matches STUCK file\n";
if ($datasetname =~ /_Fail(\d+)$/) {
    $threshold = int($1)/100.; 
    print "Probability of FAILED files: $threshold\n"; 
}


if ($status eq 'pre') {
    print "pre-validation test\n";
    if ($filename =~ /-stuckfile$/) {
        print "fake validation failure\n";
        exit(3);
    }
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
    if (($r < $threshold)||($filename =~ /-stuckfile$/)) {
	print "post-validation failure\n";
	exit(1);
    } else {
	print "post-validation success\n";
	exit(0);
    }
}
