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
use UtilsBlockConsistencyCheck;

my ($dbh,$conn,$dbconfig,$r,$s);
my ($nodes,@nodes,$help,$bcc);
my ($id,$block,$n_files,$n_tested,$n_ok,$status,$test,$time_reported);
my ($debug_me);
my ($detail);

$debug_me = 1;
$detail = 0;
$n_files  = 0;
GetOptions(	"db=s"		=> \$dbconfig,
		"node=s"	=> \@nodes,
		"detail"	=> \$detail,

		"help|h"	=> sub { &usage() }
          );

#-------------------------------------------------------------------------------
$dbconfig or die "'--dbconfig' argument is mandatory\n";
@nodes    or die "'--node' argument is mandatory\n";

$conn = { DBCONFIG => $dbconfig };
$dbh = &connectToDatabase ( $conn, 0 );

#-------------------------------------------------------------------------------
$nodes = expandNodeList(@nodes);

$bcc = UtilsBlockConsistencyCheck->new( DBH => $dbh );
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
  if ( $detail && $s->{STATUS} eq 'Fail' )
  {
    my $f = $bcc->getDetailedTestResults($s->{ID});
    foreach ( @{$f} )
    {
      print "Block=$s->{BLOCK} test=$s->{TEST} LFN=$_->{LOGICAL_NAME} Status=$_->{STATUS}\n";
    }
  }
}

exit 0;

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Everything below here should find its way into a Perl module at some point
#-------------------------------------------------------------------------------
sub dvsDetailedTestResults
{
die "Redundant...\n";
  my $request = shift;
  my ($sql,$q,@r);

  $sql = qq{ select logical_name, name status from t_dps_file f
		join t_dvs_file_result r on f.id = r.fileid
		join t_dvs_status s on r.status = s.id
		where request = :request and status in
		 (select id from t_dvs_status where not
				(name = 'OK' or name = 'None' ) )
	   };

  $q = execute_sql( $sql, ( ':request' => $request ) );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

  return \@r;
}

sub dvsTestResults
{
die "Redundant...\n";
  my ($sql,$q,$nodelist,@r);

  $nodelist = join(',',@_);
  $sql = qq{ select v.id, b.name block, n_files, n_tested, n_ok,
	     s.name status, t.name test, time_reported
	     from t_status_block_verify v join t_dvs_status s on v.status = s.id
	     join t_dps_block b on v.block = b.id
	     join t_dvs_test t on v.test = t.id
	     where node in ($nodelist) and status > 0
	     order by s.id, time_reported
	   };

  $q = execute_sql( $sql, () );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

  return \@r;
}

#-------------------------------------------------------------------------------
sub expandNodeList
{
  my ($item,%result,$sql);
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
