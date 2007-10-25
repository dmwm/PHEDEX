#!/usr/bin/env perl
use strict;

##H
##H  Inject block-test requests in TMDB, for the BlockDownloadVerify agent
##H
##H  This help is far from complete, ask Tony if you want to use this script.
##H
##H  Options:
##H 
##H   --db = DBCONFIG     The usual PhEDEx db configuration file
##H   --node = <string>   PhEDEx node to search for replicas
##H   --block = <string>  Block to queue for testing
##H   --test = <string>   Test to queue for these blocks
##H   --n_files = <num>   Number of files to analyse in the block
##H   --expire = <num>    Seconds till this request expires
##H   --priority = <num>  Priority for these requests
##H 
##H   --debug, --verbose  Obvious...
##H   --listonly          List the blocks, buffers, and tests matching
##H                       the input arguments.
##H
##H  Wildcards are accepted where they are sensible, defaults are provided
##H  where they make sense too.
##H 

# Process command line arguments.
use Getopt::Long;
use PHEDEX::Core::Help;
use PHEDEX::Core::DB;
use PHEDEX::Core::Catalogue;
use PHEDEX::BlockConsistency::Core;

my ($dbh,$conn,$dbconfig);
my (@nodes,$nodes,$node,@blocks,$blocks,$block,@tests,$tests,$test);
my ($help,$verbose,$debug,$listonly,$count,$id);
my ($bcc,$n_files,$time_expire,$priority,$use_srm);
my ($debug_me);

$debug_me = 1;
$verbose = $debug = $listonly = 0;

$n_files = $use_srm = 0;
$priority = 16384;
$time_expire = 10 * 86400;
GetOptions(	"db=s"		=> \$dbconfig,
		"node=s"	=> \@nodes,
		"block=s"	=> \@blocks,
		"test=s"	=> \@tests,

		"n_files=i"	=> \$n_files,
		"expire=i"	=> \$time_expire,
		"priority=i"	=> \$priority,
		"use_srm"	=> \$use_srm,

		"debug+"	=> \$debug,
		"verbose+"	=> \$verbose,
		"listonly"	=> \$listonly,

		"help|h"	=> sub { &usage() }
          );

#-------------------------------------------------------------------------------
$dbconfig or die "'--dbconfig' argument is mandatory\n";
@nodes    or die "'--node' argument is mandatory\n";
@blocks   or die "'--block' argument is mandatory\n";
@tests    or die "'--test' argument is mandatory\n";
$use_srm = $use_srm ? 'y' : 'n';

if ( $n_files )
{
  print "Warning: '--n_files' not supported yet. Resetting it...\n";
  $n_files = 0;
}
$conn = { DBCONFIG => $dbconfig };
$dbh = &connectToDatabase ( $conn, 0 );

#-------------------------------------------------------------------------------
$bcc = PHEDEX::BlockConsistency::Core->new( DBH => $dbh );
$nodes = $bcc->getBuffersFromWildCard(@nodes);
my @n = keys %{$nodes};
$blocks  = $bcc->expandBlockListOnNodes( blocks => \@blocks,
					 nodes  => \@n );
$tests   = $bcc->expandTestList(@tests);

if ( $listonly || $verbose > 1 )
{
  map { print "Node=",  $nodes->{$_}->{NAME}, "\n" } keys %{$nodes};
  map { print "Block=", $blocks->{$_}->{NAME},"\n" } keys %{$blocks};
  map { print "Test=",  $tests->{$_}->{NAME}, "\n" } keys %{$tests};
  print "Got ", scalar keys %{$nodes},  " nodes\n";
  print "Got ", scalar keys %{$blocks}, " blocks\n";
  print "Got ", scalar keys %{$tests},  " tests\n";

  exit 0 if $listonly;
}

# For now, limit to a single node...
die "Can only handle one node at a time at the moment, sorry.\n",
	"(Your input matched '",
	join("', '",sort map {$nodes->{$_}->{NAME} } keys %{$nodes}),
	"')\n"
	unless  scalar keys %{$nodes} == 1;
@nodes = keys %{$nodes};
$node = $nodes[0];
$count = scalar keys %{$blocks};
print "Preparing for $count test-insertions\n";
$|=1;

foreach $block ( keys %{$blocks} )
{
  my $n = $n_files || $blocks->{$block}{FILES};
  foreach $test ( keys %{$tests} )
  {
    $id = $bcc->InjectTest( node	=> $node,
			    test	=> $test,
			    block	=> $block,
			    n_files	=> $n,
			    time_expire	=> time + $time_expire,
			    priority	=> $priority,
			    use_srm	=> $use_srm,
		          );
    defined $id or die "InjectTest failed miserably :-(\n";
    $verbose && print "Request=$id Node=$nodes->{$node}->{NAME} test=\'$tests->{$test}->{NAME}\' block='$blocks->{$block}->{NAME}'\n";
  }
  $count--;
  $verbose || print "Insertions remaining: $count \r";
  $dbh->commit();
}
print "\n";
$|=0;

print "All done...\n";
