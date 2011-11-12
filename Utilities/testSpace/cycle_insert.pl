#!/usr/bin/env perl
use strict;
use warnings;
use Time::Local;
use File::Basename;
use Getopt::Long;

my ($times, $i, $j, $now, $past, %stat);
GetOptions(
           "times=s"      => \$times,
          );
for ($j = 2; $j < 10; $j++) {
   #$now = time();
   #print "current time", $now, "\n";
   #put timestamp cycle outside spaceInsert
   #for ($i = 1040; $i < 1040+$times; $i++) {
   # put timestamp cycle inside spaceInsert
   system("/data/zxm/PHEDEX/Utilities/testSpace/spaceInsert --dump /data/zxm/PHEDEX/perl_lib/PHEDEX/Namespace/chimera_dump_201110190705.xml --time $times --collName level$j --level $j chimera_dump");
   #} 
   #$past = time() - $now;
   #$stat{$j} = $past; 
   #print "level",$j," use time : ", $past, "\n"; 
}

#foreach  (keys %stat) {
#  print "level ",$_," use time : ", $stat{$_}, "\n"; 
#}


