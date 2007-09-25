#!/usr/bin/env perl
use strict;

##H
##H  Report block-test results from the BlockDownloadVerify agent
##H
##H  This help is far from complete, ask Tony if you want to use this script.
##H
##H  Options:
##H 
##H   --db = DBCONFIG     The usual PhEDEx db configuration file
##H   --node = <string>   PhEDEx node to search for replicas
##H 

# Process command line arguments.
use Getopt::Long;
use PHEDEX::Core::Help;
use PHEDEX::Core::DB;
use PHEDEX::Core::Catalogue;
use PHEDEX::BlockConsistency::Core;

my ($dbh,$conn,$dbconfig,$r,$s);
my ($nodes,@nodes,$help,$bcc);
my ($id,$block,$n_files,$n_tested,$n_ok,$status,$test,$time_reported);
my ($debug_me);
my ($detail,%states,@states,$all_states);

$debug_me = 1;
$detail = 0;
$n_files  = 0;
GetOptions(	"db=s"	 => \$dbconfig,
		"node=s" => \@nodes,
		"detail" => \$detail,

		"help|h" => sub { &usage() }
          );

#-------------------------------------------------------------------------------
$dbconfig or die "'--db' argument is mandatory\n";
@nodes    or die "'--node' argument is mandatory\n";

$conn = { DBCONFIG => $dbconfig };
$dbh = &connectToDatabase ( $conn, 0 );

#-------------------------------------------------------------------------------
$bcc   = PHEDEX::BlockConsistency::Core->new( DBH => $dbh );
$nodes = $bcc->expandNodeList(@nodes);

$all_states = 'All-states';
$states{$all_states} = $bcc->getTestsPendingCount(keys %{$nodes});
push @states, $all_states;

$r = $bcc->getTestResults(keys %{$nodes});
printf("%24s %6s %7s %7s %7s %10s %10s %s\n",
	  'Time Reported',
	  'Node',
	  'ID',
	  'NFiles',
	  'NTested',
	  'NOK',
	  'Test',
	  'Status',
	  'Block'
      );
foreach $s ( @{$r} )
{
  printf("%24s %6d %15s %7d %7d %7d %10s %10s %s\n",
	  scalar localtime $s->{TIME_REPORTED},
	  $s->{ID},
	  $s->{NODE},
	  $s->{N_FILES},
	  $s->{N_TESTED},
	  $s->{N_OK},
	  $s->{TEST},
	  $s->{STATUS},
	  $s->{BLOCK} || "#$s->{BLOCKID}",
	);

  if ( ! $states{$s->{STATUS}}++ ) { push @states, $s->{STATUS}; }
  if ( $detail && $s->{STATUS} eq 'Fail' )
  {
    my $f = $bcc->getDetailedTestResults($s->{ID});
    foreach ( @{$f} )
    {
      print "Block=$s->{BLOCK} test=$s->{TEST} LFN=$_->{LOGICAL_NAME} Status=$_->{STATUS}\n";
    }
  }
}

if ( @states )
{
  print "State count summary:\n";
  foreach ( @states )
  {
    print "State=$_ count=$states{$_}\n";
  }
}
