#!/usr/bin/env perl
use strict;
use warnings;
use PHEDEX::Core::Loader;
use Data::Dumper;
use PHEDEX::Core::DB;

my $db =  $ENV{'DBPARAM'};
my ($conn,$dbh);
sub hr {
  my $length = shift;
  for (1.. $length) { print "_"; }; print "\n"; 
}

my ($table, $results, $aref, $line, $format);

$table = $ARGV[0];
print $table . "\n";

$conn =  { DBCONFIG => $db };
$dbh = &connectToDatabase ($conn);
$results =  $dbh->selectall_arrayref("select * from $table");

&hr(80);
for my $i ( 0 .. @$results-1 ) {
  my $format="";
  $aref = $results->[$i];
  $line =   join "\t",@$aref;
  for (1 .. @$aref) {
    $format = $format . "%-20s";
  };
  $format = $format . "\n";
  printf  ( $format , @$aref );
}
&hr(80);
&disconnectFromDatabase($conn, $dbh, 1);
exit;

