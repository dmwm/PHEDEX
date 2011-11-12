#!/usr/bin/env perl
use strict;
use warnings;
use Time::Local;
use File::Basename;
use Getopt::Long;

my ($times, $input, $i, $j, $now, $past, %stat);
GetOptions(
           "times=s"      => \$times,
          );
for ($j = 2; $j < 10; $j++) {
   $now = time();
   # do querying with spaceQuery
   #system("/data/zxm/PHEDEX/Utilities/testSpace/spaceQuery --collName level$j --time_since 1299 -time_until 1400");
   $input = "collName=level".$j."&time_since=1299&time_until=1400";
   print "input:", $input, "\n";
   # do querying with curl
   system("curl -k 'https://pheSpaceMon.cern.ch/phedex/datasvc/perl/debug/mongo?$input'");
   $past = time() - $now;
   $stat{$j} = $past; 
}

#print out the time used
foreach  (keys %stat) {
  print "level ",$_," use time : ", $stat{$_}, "\n"; 
}
