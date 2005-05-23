#!/usr/bin/env perl

use strict;
use warnings;

my $pool_cat = $ARGV[0];
my $node = $ARGV[1];
my $guid = $ARGV[2];
my $pfn = $ARGV[3];
my $xml = $ARGV[4];

# check, that we got all argument we need
if (scalar(@ARGV) != 5) {
    print "not all arguments for publish script set.\n";
    print "argument 1: POOL contact string for local catalogue\n";
    print "argument 2: node suffix\n";
    print "argument 3: GUID to publish\n";
    print "argument 4: localized PFN\n";
    print "argument 5: Path to xml pool fragment\n";
    exit 5;
}

# change PFN to local access
my $locpfn = "$pfn"."_"."$node";


#check if we already have a copy of the GUID
#in this case just add the replica to the POOL catalogue
if (`FClistPFN -u $pool_cat -q "guid='$guid'"`) {
    my $cmd="FCaddReplica -u $pool_cat -r $locpfn -g $guid >& /dev/null";
    my $err = system($cmd);
    if ($err) {
	print "couldn't add local PFN to POOL catalogue (exit 1)\n";
	exit 1;
    }
} else {
# if we don't know the GUID at all, we have to publish all information
# to the POOL catalogue (metadata and stuff)
    
# add the local PFN to the catalogue fragment
    my $cmd="FCaddReplica -u xmlcatalog_file:$xml -r $locpfn -g $guid";
    my $err = system($cmd);
    if ($err) {
	print "couldn't add local PFN to catalogue fragment (exit 2)\n";
	exit 2;
    }
# delete old PFN from catalogue fragment
    $cmd="FCdeletePFN -u xmlcatalog_file:$xml -p $pfn";
    $err = system($cmd);
    if ($err) {
	print "couldn't delete PFN from catalogue fragment (exit 3)\n";
	exit 3;
    }
# publish the catalogue fragment too POOL
    $cmd="FCpublish -u xmlcatalog_file:$xml -d $pool_cat >& /dev/null";
    $err = system($cmd);
    if ($err) {
	print "couldn't publish fragment to POOL (exit 4)\n";
	exit 4;
    }
}
exit 0;

