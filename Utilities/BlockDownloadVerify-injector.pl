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

BEGIN {
    $^W = 1; use strict; use warnings;
    our $me = $0; $me =~ s|.*/||;
    our $home = $0;
    if ( $home !~ m%/% ) { $home = '.'; }
    $home =~ s|/[^/]+$||;
    $home ||= ".";
    $home .= "/../Toolkit/Common";
    unshift(@INC, $home);
}

# Process command line arguments.
use Getopt::Long;
use UtilsHelp;
use UtilsDB;
use UtilsCatalogue;
use PHEDEX::BlockConsistency::Core;

my ($dbh,$conn,$dbconfig);
my (@nodes,$nodes,$node,@blocks,$blocks,$block,@tests,$tests,$test);
my ($help,$verbose,$debug,$listonly,$count,$id);
my ($bcc,$n_files,$time_expire,$priority);
my ($debug_me);

$debug_me = 1;
$verbose = $debug = $listonly = 0;

$n_files  = 0;
$priority = 16384;
$time_expire = 10 * 86400;
GetOptions(	"db=s"		=> \$dbconfig,
		"node=s"	=> \@nodes,
		"block=s"	=> \@blocks,
		"test=s"	=> \@tests,

		"n_files=i"	=> \$n_files,
		"expire=i"	=> \$time_expire,
		"priority=i"	=> \$priority,

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

if ( $n_files )
{
  print "Warning: '--n_files' not supported yet. Resetting it...\n";
  $n_files = 0;
}
$conn = { DBCONFIG => $dbconfig };
$dbh = &connectToDatabase ( $conn, 0 );

#-------------------------------------------------------------------------------
$nodes = expandNodeList(@nodes);
#$blocks  = expandBlockList(@blocks);
$blocks  = expandBlockListOnNode(@blocks);
$tests   = expandTestList(@tests);

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

$bcc = PHEDEX::BlockConsistency::Core->new( DBH => $dbh );
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
exit 0;

#-------------------------------------------------------------------------------
sub DumpTable
{
  my ($k,$t) = @_;
  my $sql = 'select ' . join(', ',@{$k}) . " from $t";
  my $r = select_all( $sql );
  foreach ( @{$r} )
  {
    print "insert into $t (", join(', ', @{$k}), ") ",
          " values( '", join("','", @{$_}), "');\n"; 
  }
}

#-------------------------------------------------------------------------------
# Everything below here should find its way into a Perl module at some point
#-------------------------------------------------------------------------------
sub expandNodeList
{
  my ($item,%result);
  foreach my $item ( @_ )
  {
    $debug && print "Getting nodes with names like '$item'\n";
    my $tmp = getNodeFromWildCard($item);
    map { $result{$_} = $tmp->{$_} } keys %$tmp;
  }
  return \%result;
}

#-------------------------------------------------------------------------------
sub expandBlockList
{
  my ($item,%result);
  foreach my $item ( @_ )
  {
    $debug && print "Getting blocks with names like '$item'\n";
    my $tmp = getBlocksFromWildCard($item);
    map { $result{$_}++ } @{$tmp};
  }
  my @x = keys %result;
  return \@x;
}

#-------------------------------------------------------------------------------
sub expandBlockListOnNode
{
  my ($item,%result);
  foreach my $item ( @_ )
  {
    $debug && print "Getting blocks with names like '$item'\n";
    my $tmp = getBlockReplicasFromWildCard($item);
    map { $result{$_} = $tmp->{$_} } keys %$tmp;
  }
  return \%result;
}

#-------------------------------------------------------------------------------
sub expandTestList
{
  my ($item,%result);
  foreach my $item ( @_ )
  {
    $debug && print "Getting tests with names like '$item'\n";
    my $tmp = getTestsFromWildCard($item);
    map { $result{$_} = $tmp->{$_} } keys %$tmp;
  }
  return \%result;
}

#-------------------------------------------------------------------------------
sub getNodeFromWildCard
{
  my $sql =
        qq {select id, name, technology from t_adm_node
		 where upper(name) like :node };
  my %p = ( ":node" => uc shift );
  my $r = select_hash( $sql, 'ID', %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlockReplicasFromWildCard
{
  my $sql = qq {select block, name, files from t_dps_block_replica br join t_dps_block b on br.block = b.id where name like :block_wild and node in };
  $sql .= '(' . join(',',keys %{$nodes}) . ')';

  my %p = ( ':block_wild' => @_ );
  my $r = select_hash( $sql, 'BLOCK', %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksFromWildCard
{
  my $sql = qq {select name from t_dps_block where name like :block_wild};
  my %p = ( ":block_wild" => @_ );
  my $r = select_single( $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getTestsFromWildCard
{
  my $sql = qq {select id, name from t_dvs_test
		 where name like lower(:test_wild)};
  my %p = ( ":test_wild" => @_ );
  my $r = select_hash( $sql, 'ID', %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub select_single
{
  my ( $query, %param ) = @_;
  my ($q,@r);

  $q = execute_sql( $query, %param );
  @r = map {$$_[0]} @{$q->fetchall_arrayref()};
  return \@r;
}

#-------------------------------------------------------------------------------
sub select_all
{
  my ( $query ) = @_;
  my ($q,@r);

  $q = execute_sql( $query, () );
  @r = @{$q->fetchall_arrayref()};
  return \@r;
}

#-------------------------------------------------------------------------------
sub select_hash
{
  my ( $query, $key, %param ) = @_;
  my ($q,$r);

  $q = execute_sql( $query, %param );
  $r = $q->fetchall_hashref( $key );

  my %s;
  map { $s{$_} = $r->{$_}; delete $s{$_}{$key}; } keys %$r;
  return \%s;
}

#-------------------------------------------------------------------------------
sub execute_sql
{
  my ( $query, %param ) = @_;
  my ($q,$r);

  if ( $query =~ m%\blike\b%i )
  {
    foreach ( keys %param ) { $param{$_} =~ s%_%\\_%g; }
    $query =~ s%like\s+(:[^\)\s]+)%like $1 escape '\\' %gi;
  }

  if ( $debug )
  {
    print " ==> About to execute\n\"$query\"\nwith\n";
    foreach ( sort keys %param ) { print "  \"$_\" = \"$param{$_}\"\n"; }
    print "\n";
  }
  $q = &dbexec($dbh, $query, %param);
  return $q;
}
