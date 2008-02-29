#!/usr/bin/env perl
use strict;

##H
##H  Report block-test results from the BlockDownloadVerify agent
##H
##H  This help is far from complete, see the wiki for more details. The URL
##H is https://twiki.cern.ch/twiki/bin/view/CMS/BlockDownloadVerify
##H
##H  Options:
##H 
##H   --db DBCONFIG     The usual PhEDEx db configuration file
##H   --node <string>   PhEDEx nodes to limit the result-set
##H   --block <string>  Wildcard block string to limit the result-set
##H   --age <integer>   Limit report to tests updated so many seconds ago
##H   --days <integer>  Limit report to tests updated so many days ago
##H   --summary         Obvious...
##H   --detail          Obvious...
##H 

# Process command line arguments.
use Getopt::Long;
use PHEDEX::Core::Help;
use PHEDEX::Core::DB;
use PHEDEX::Core::Catalogue;
use PHEDEX::BlockConsistency::Core;

my ($dbh,$conn,$dbconfig,$r,$s,$block);
my ($nodes,@nodes,$help,$bcc);
my ($status,$test,$time_reported);
my ($debug_me,$age,$days,$h);
my ($detail,$summary,%states,@states,$all_states);

$debug_me = 1;
$detail = $age = 0;
GetOptions(	"db=s"	  => \$dbconfig,
		"node=s"  => \@nodes,
		"block=s" => \$block,
		"age=i"   => \$age,
		"days=f"  => \$days,
		"detail"  => \$detail,
		"summary" => \$summary,

		"help|h" => sub { &usage() }
          );

#-------------------------------------------------------------------------------
$dbconfig or die "'--db' argument is mandatory\n";
$summary && $detail && die "Make your mind up please, summary _or_ detail!'n";

$conn = { DBCONFIG => $dbconfig };
$dbh = &connectToDatabase ( $conn );

#-------------------------------------------------------------------------------
$bcc   = PHEDEX::BlockConsistency::Core->new( DBH => $dbh );
$nodes = $bcc->getBuffersFromWildCard(@nodes) if @nodes;

$age = int($days * 86400) if $days;
$age = 86400 unless $age;

print "Reporting results within the last $age seconds (";
printf "%.2f",(100*$age/86400)/100;
print " days)\n";

$age = time - $age;
$all_states = 'All-states';
$states{$all_states} = $bcc->getTestsPendingCount(
						   nodes => [keys %{$nodes}],
						   TIME_EXPIRE => $age,
						 );
push @states, $all_states;

$r = $bcc->getTestResults(
			   nodes => [keys %{$nodes}],
			   TIME_REPORTED => $age,
			   BLOCK	 => $block,
			 );
printf("%24s %6s %15s %7s %7s %7s %10s %10s %s\n",
	  'Time Reported',
	  'ID',
	  'Node',
	  'NFiles',
	  'NTested',
	  'NOK',
	  'Test',
	  'Status',
	  'Block'
      )
  unless $summary;
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
	)
  unless $summary;

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
