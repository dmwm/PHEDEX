#!/usr/bin/env perl

if (!@ARGV) {
    print STDERR "$0: No pfns given\n";
    exit 1;
} 

my @args = map { "-M $_" } @ARGV;

if (system("stager_get @args")){
   print STDERR "$0: stager_get @args returns error\n"; 
}
