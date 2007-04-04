#!/usr/bin/perl

###############################################################################
# Script to analyze the PhEDEx download daemon log. Works with PhEDEx 2.5.x
#
# Author: Derek Feichtinger <derek.feichtinger@psi.ch>
#
# Version info: $Id: InspectPhedexLog.pl,v 1.3 2007/04/02 10:38:49 dfeichti Exp $:
###############################################################################

use strict;
use Getopt::Std;
use Data::Dumper;
use Date::Manip qw(ParseDate UnixDate);
use Time::Local;

my $flag_showErrors=0;
my $flag_rawErrors=0;
my $flag_verbose=0;
my $flag_debug=0;
my $flag_checkdate=0;
my $flag_bunchDetect=0;

sub usage {
print <<"EOF";
usage: InspectPhedexLog [options] logfile1 [logfile2 ...]

   Analyses PhEDEx download agent log files

   options:
      -e    also show error statistics (summary over error messages)
         -r    do not try to regexp-process errors messages, but show raw error messages
      -v    verbose   Prints task IDs for the collected errors (useful for closer investigation)
      -s    start_date   -t end_date

      -b    bunch detection and rate calculation
            (still some problems with correct bunch detection. leading to strange rates for some
             source logs. Do not rely on this).
      -d    debug   Prints a summary line for every single transfer
      -h    display this help

 examples:
   InspectPhedexLog.pl Prod/download
   InspectPhedexLog.pl -evs yesterday -t "2006-11-20 10:30:00" Prod/download
   InspectPhedexLog.pl -es "-2 days"  Prod/download

   without any of the special options, the script will just print
   summary statistics for all download sources.

   Running with the -e option is probably the most useful mode to identify site problems

EOF

}

# A note about the time values used in PhEDEx
#
# t-expire: time when transfer task is going to expire 
# t-assing: time when transfer task was assigned (task was created)
# t-export: time when files where marked as available at source
# t-inxfer: time when download agent downloaded task the file belongs to.
# t-xfer: time when transfer for that particular file starts
# t-done: time when transfer for that particular file finished
#
# Note from D.F.:
# This is not quite correct. Several files in a sequence always get the
# same t-xfer value and nearly identical t-done values (the t-done value
# differences are <0.1s). So these times seem to refer rather to a
# bunch of files and not to the times of particular files.



# OPTION PARSING
my %option=();
getopts("bdehrs:t:v",\%option);


$flag_bunchDetect=1 if(defined $option{"b"});
$flag_showErrors=1 if(defined $option{"e"});
$flag_rawErrors=1 if(defined $option{"r"});
$flag_verbose=1 if(defined $option{"v"});
$flag_debug=1 if(defined $option{"d"});

if (defined $option{"h"}) {
   usage();
   exit 0;
}

my ($dstart,$dend)=(0,1e20);
if (defined $option{"s"}) {
   my $tmp=ParseDate($option{"s"});
   die "Error: Could not parse starting date: $option{s}\n" if (!$tmp);
   $dstart=UnixDate($tmp,"%s");
   #my ($s,$m,$h,$D,$M,$Y) = UnixDate($tmp,"%S","%M","%H","%d","%m","%Y");
   #print "Starting Date: $Y $M $D  $h $m $s ($dstart)\n"; 
   $flag_checkdate=1; 
}
if (defined $option{"t"}) {
   my $tmp=ParseDate($option{"t"});
   die "Error: Could not parse end date: $option{t}\n" if (!$tmp);
   $dend=UnixDate($tmp,"%s");
   $flag_checkdate=1; 
}
   

my @logfiles=@ARGV;

my %sitestat;
my %failedfile;

if ($#logfiles==-1) {
   usage();
   die "Error: no logfile(s) specified\n";
}

my ($datestart,$dateend,$date_old)=0;
my %errinfo;
my ($date,$task,$from,$stat,$size,$txfer,$tdone,$ttransfer,$fname,$reason,$bsize,$size_sum);
my ($bunchsize,$bunchfiles,$txfer_old,$tdone_old,$closedbunch);
my $line;
my $statstr;
foreach my $log (@logfiles) {
   open(LOG,"<$log") or die "Error: Could not open logfile $log";
   my ($MbperS,$MBperS);
   while($line=<LOG>) {
      if ($line =~ /xstats.*report-code=.*/) {

         ($date,$task,$from,$stat,$size,$txfer,$tdone,$fname) = $line =~
            m/(\d+-\d+-\d+\s+\d+:\d+:\d+):.*task=([^\s]+).*from=([^\s]+).*report-code=([\d-]+).*size=([^\s]+).*t-xfer=([^\s]+).*t-done=([^\s]+).*lfn=([^\s]+)/;
         # report-code=0 means a successful transfer
	 if(! $fname) {
	   die "Error: Parsing problem with line:\n$line";
	 }

         if($flag_checkdate) {
            my ($Y,$M,$D,$h,$m,$s) = $date =~ m/(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)/;
            #print "$line\n$date   $Y,$M,$D,$h,$m,$s\n"; #    $epdate $dstart $dend \n";
            my $epdate=timelocal($s,$m,$h,$D,$M-1,$Y);
            next if $epdate < $dstart or $dend < $epdate;
         }

         $dateend=$date; # TODO

	 $closedbunch=0;
         if($stat == 0) {   # successful transfer
             $statstr="OK    ";  ##### sprintf("OK(%4d)  ",$stat);
             $sitestat{"$from"}{"OK"}++;
             $sitestat{"$from"}{"size"}+=$size;
             $sitestat{"$from"}{"ttransfer"}+=$ttransfer;
             delete $failedfile{"$fname"} if exists $failedfile{"$fname"};

             # the following is needed because transfer time applies not to a single file but to the bunch
	     if($txfer == $txfer_old || $txfer_old == 0) {     # try to identify bunches
	       printf STDERR ("WARNING: there may be a transfer time problem (delta t-done=%.4f) in line\n$line\n",$tdone-$tdone_old) if $flag_bunchDetect && abs($tdone-$tdone_old) > 0.2 && $txfer_old != 0;
	       $bunchfiles++;
	       $bunchsize += $size;
	     } else {
                 $closedbunch=1;
	     }
	     #printf ("DEBUG: DIFF %.5f   txfer %.5f    tdone %.5f  \n",$ttransfer - $ttransfer_old,
             #$txfer-$txfer_old, $tdone-$tdone_old);
	     ($txfer_old,$tdone_old) = ($txfer,$tdone);

         } else {
             $failedfile{"$fname"}++;
             $statstr="FAILED";  #sprintf("FAILED(%4d)",$stat);
             $sitestat{"$from"}{"FAILED"}++;

	     # try to collect error information in categories. This needs to be extended for the myriad of SRM
	     # error messages ;-)
	     my ($detail,$validate) = $line =~ m/.*detail=\((.*)\)\s*validate=\((.*)\)\s*$/;
	     if(! $flag_rawErrors) {
	       my $tmp;
	       $detail =~ s/\sid=\d+\s/id=\[id\]/;
	       $detail =~ s/srm:\/\/[^\s]+/\[srm-URL\]/;
	       if( $detail=~/^\s*$/) {$reason = "(No detail given)"}
	       elsif( (($reason) = $detail =~ m/.*(the server sent an error response: 425 425 Can't open data connection).*/)) {}
	       elsif( (($reason) = $detail =~ m/.*(the gridFTP transfer timed out).*/) ) {}
	       elsif( (($reason) = $detail =~ m/.*(Failed SRM get on httpg:.*)/) ) {}
	       elsif( (($reason,$tmp) = $detail =~ m/.*(ERROR the server sent an error response: 553 553)\s*[^\s]+:(.*)/) )
		 {$reason .= " [filename]: " . $tmp}
	       else {$reason = $detail};
	     } else {$reason = $detail};
	     $errinfo{$from}{$reason}{num}++;
	     push @{$errinfo{$from}{$reason}{tasks}},$task;
         }

#         ($date_old,$from_old,$ttransfer_old)=($date,$from,$ttransfer);

         $datestart=$date if !$datestart;

	 if($closedbunch) {
	   $ttransfer = $tdone_old - $txfer_old;
	   die "ERROR: ttransfer=0 ?????? in line:\n $line\n" if $ttransfer == 0;
	   $MbperS=$bunchsize*8/$ttransfer/1e6;
	   $MBperS=$bunchsize/1024/1024/$ttransfer;
	   printf("   *** Bunch:  succ. files: $bunchfiles  size=%.2f GB  transfer_time=%.1f s (%.1f MB/s = %.1f Mb/s)\n"
		  ,$bunchsize/1024/1024/1024,$ttransfer,$MBperS,$MbperS) if $flag_debug && $flag_bunchDetect;

	   $bunchfiles = 1;
	   $bunchsize = $size;
	 }
	 printf("$statstr $from  $fname  size=%.2f GB $date\n",$size/1024/1024/1024)  if $flag_debug;
      }

   }

   close LOG;

 }


if($flag_showErrors) {
   print "\n\n==============\n";
   print "ERROR ANALYSIS\n";
   print "==============\n";
   print "\nRepeatedly failing files that never were transferred correctly:\n";
   print   "===============================================================\n";
   foreach my $fname (sort {$failedfile{$b} <=> $failedfile{$a}} keys %failedfile) {
      printf("   %3d  $fname\n",$failedfile{"$fname"}) if $failedfile{"$fname"} > 1;
   }


   print "\n\nError message statistics per site:\n";
   print "===================================\n";
      foreach $from (keys %errinfo) {
         print "\n *** ERRORS from $from:***\n";
         foreach $reason (sort { $errinfo{$from}{$b}{num} <=> $errinfo{$from}{$a}{num} } keys %{$errinfo{$from}}) {
            printf("   %4d   $reason\n",$errinfo{$from}{$reason}{num});
	    print "             task IDs: ", join(",",@{$errinfo{$from}{$reason}{tasks}}) . "\n\n" if $flag_verbose;
         }
      }

   }
print "\nSITE STATISTICS:\n";
print "==================\n";
print "                         first entry: $datestart      last entry: $dateend\n";

my ($MbperS,$MBperS);
foreach my $site (keys %sitestat) {
    $sitestat{$site}{"OK"}=0 if ! defined $sitestat{$site}{"OK"};
    $sitestat{$site}{"FAILED"}=0 if ! defined $sitestat{$site}{"FAILED"};
    print "site: $site (OK: " . $sitestat{$site}{"OK"} . " / Err: " . $sitestat{$site}{"FAILED"} . ")";
    printf("\tsucc. rate: %.1f %", $sitestat{$site}{"OK"}/($sitestat{$site}{"OK"}+$sitestat{$site}{"FAILED"})*100) if ($sitestat{$site}{"OK"}+$sitestat{$site}{"FAILED"}) > 0;
    printf("   total: %.1f GB",$sitestat{$site}{"size"}/1e9);

    if ($sitestat{$site}{"ttransfer"}>0) {
      $MbperS=$sitestat{$site}{"size"}*8/$sitestat{$site}{"ttransfer"}/1e6;
      $MBperS=$sitestat{$site}{"size"}/1024/1024/$sitestat{$site}{"ttransfer"};
      printf("   avg. rate: %.1f MB/s = %.1f Mb/s",$MBperS,$MbperS) if $flag_bunchDetect;
    }
    print "\n";
}
