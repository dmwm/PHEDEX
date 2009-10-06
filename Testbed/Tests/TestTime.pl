#!/usr/bin/env perl

use warnings;
use strict;

use PHEDEX::Core::Timing;
use POSIX qw(mktime strftime);

my $fmt = "%-35s %s\n";

# get a test timestamp
my $test = time();
printf $fmt, "test timestamp", $test;
my $gmnow = PHEDEX::Core::Timing::gmnow();
printf $fmt, "gmnow timestamp", $gmnow;

# observe human-formatted GMT time
my @gmtest = gmtime($test);
printf $fmt, "gmtime of test", join(',',@gmtest);
my $dtgmt = strftime("%Y-%m-%d %H:%M:%S", @gmtest);
printf $fmt, "datetime of test in GMT", $dtgmt;

# observe human-formatted GMT time
my @lttest = localtime($test);
printf $fmt, "localtime of test", join(',',@lttest);
my $dtlt = strftime("%Y-%m-%d %H:%M:%S", @lttest);
printf $fmt, "datetime of test in local time", $dtlt;

# parse the human-formatted GMT time
my @parsed_dtgmt = ($dtgmt =~ /(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/);
printf $fmt, "parsed GMT string", join(',',@parsed_dtgmt);

# reformat to mktime() array
my @refmt_dtgmt = reverse @parsed_dtgmt;
$refmt_dtgmt[5] -= 1900; # reformat year
$refmt_dtgmt[4] -= 1;    # reformat month
printf $fmt, "reformatted array for mktime", join(',',@refmt_dtgmt);

# try to get back to our test time stamp
my $gmmktime_test = gmmktime(@refmt_dtgmt);
printf $fmt, "gmmktime timestamp", $gmmktime_test;
my $mktime_test = mktime(@refmt_dtgmt);
printf $fmt, "mktime timestamp", $mktime_test;
printf $fmt, "test == gmmktime round-trip?", $test == $gmmktime_test ? "TRUE" : "FALSE";

exit 0;
