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

my ($dbh,$conn,$dbconfig,$r,$s);
my ($nodes,@nodes,$help,$bcc);
my ($id,$block,$n_files,$n_tested,$n_ok,$status,$test,$time_reported);
my ($debug_me);
my ($detail,%states,@states);

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
$nodes = expandNodeList(@nodes);

my $all_states = 'All-states';
$states{$all_states} = dvsTestsPending(keys %{$nodes});
push @states, $all_states;

$bcc = PHEDEX::BlockConsistency::Core->new( DBH => $dbh );
$r = $bcc->getTestResults(keys %{$nodes});
printf("%24s %6s %7s %7s %7s %10s %10s %s\n",
	  'Time Reported',
	  'ID',
	  'NFiles',
	  'NTested',
	  'NOK',
	  'Test',
	  'Status',
	  'Block Name'
      );
foreach $s ( @{$r} )
{
  printf("%24s %6d %7d %7d %7d %10s %10s %s\n",
	  scalar localtime $s->{TIME_REPORTED},
	  $s->{ID},
	  $s->{N_FILES},
	  $s->{N_TESTED},
	  $s->{N_OK},
	  $s->{TEST},
	  $s->{STATUS},
	  $s->{BLOCK}
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

exit 0;

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Everything below here should find its way into a Perl module at some point
#-------------------------------------------------------------------------------

sub dvsTestsPending
{
  my ($sql,$q,$nodelist,@r);

  $nodelist = join(',',@_);
  $sql = qq{ select count(*) from t_dvs_block
	     where node in ($nodelist)
	   };

  $q = execute_sql( $sql, () );
  @r = $q->fetchrow_array();

  return $r[0];
}

#-------------------------------------------------------------------------------
sub expandNodeList
{
  my ($item,%result);
  foreach my $item ( @_ )
  {
    my $tmp = getNodeFromWildCard($item);
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

  $q = &dbexec($dbh, $query, %param);
  return $q;
}
