#!/usr/bin/env perl
use warnings;
use strict;
use PHEDEX::Core::DB;
use Getopt::Long;
my ($dbparam,$self,$dbh,$help,$verbose);

GetOptions(
	    'db=s'		=> \$dbparam,
	    'help'		=> \$help,
	    'verbose'		=> \$verbose,
	  );

sub usage {
  print <<EOF;

 Usage: $0 <options>
 where <options> are:

 --db {string}	the DBParam specification for the connection

 This script will connect to the database via SQL*Plus, hiding the connection
string from the command-line so it cannot be sniffed. Use it as a direct
replacement for SQLPlus.

EOF
  exit 0;
}
$help && usage();
$dbparam || usage();

$self = { DBCONFIG => $dbparam };
PHEDEX::Core::DB::parseDatabaseInfo($self);
*IN = PHEDEX::Core::DB::sqlPlus($self);
select IN; $|=1;
#select STDOUT;
while ( <STDIN> ) {
  last if m%^q%;
  print IN;
  $verbose && print STDOUT ">> \n";
}
close IN;
$verbose && print STDOUT "All done\n";
