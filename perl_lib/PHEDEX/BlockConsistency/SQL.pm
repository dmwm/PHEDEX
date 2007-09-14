package PHEDEX::BlockConsistency::SQL;
#
# This package simply bundles the SQL statements into function calls. This
# makes them accessible to other modules.
#
# This module should be inherited by things that need it. In the case of
# multiple inheritance, make sure it's not the first item, to maintain the
# utility of $class->SUPER:: calls...
#
use strict;
use warnings;

use UtilsDB;
use UtilsCatalogue;
use Carp;

our @EXPORT = qw( );
our (%h,%params);

sub new
{
  die "Should never 'new' me! I'm a ",__PACKAGE__,"\n";
}

#sub InjectTest
#{
#  my ($self,%h,@fields,$sql,$id,%p,$q,$r);
#
#  $self = shift;
#  %h = @_;
#  @fields = qw / block node test n_files time_expire priority /;
#
#  foreach ( @fields )
#  {
#    defined($h{$_}) or die "'$_' missing in " . __PACKAGE__ . "::InjectTest!\n";
#  }
#  $r = $self->getQueued( block   => $h{block},
#			 test    => $h{test},
#			 node    => $h{node},
#			 n_files => $h{n_files}
#			);
#
#  if ( scalar(@{$r}) )
#  {
##  Silently report (one of) the test(s) that already exists...
#    return $r->[0]->{ID};
#  }
#
#  $sql = 'insert into t_dvs_block (id,' . join(',', @fields) . ') ' .
#         'values (seq_dvs_block.nextval, ' .
#          join(', ', map { ':' . $_ } @fields) .
#          ') returning id into :id';
#
#  map { $p{':' . $_} = $h{$_} } keys %h;
#  $p{':id'} = \$id;
#  $q = $self->execute_sql( $sql, %p );
#  $id or return undef;
#
## Insert an entry into the status table...
#  $sql = qq{ insert into t_status_block_verify
#        (id,block,node,test,n_files,n_tested,n_ok,time_reported,status)
#        values (:id,:block,:node,:test,:n_files,0,0,:time,0) };
#  foreach ( qw / :time_expire :priority / ) { delete $p{$_}; }
#  $p{':id'} = $id;
#  $p{':time'} = time();
#  $q = $self->execute_sql( $sql, %p );
#
## Now populate the t_dvs_file table.
#  $sql = qq{ insert into t_dvs_file (id,request,fileid,time_queued)
#        select seq_dvs_file.nextval, :request, id, :time from t_dps_file
#        where inblock = :block};
#  %p = ( ':request' => $id, ':block' => $h{block}, ':time' => time() );
#  $q = $self->execute_sql( $sql, %p );
#
#  return $id;
#}

sub getTestResults
{
  my $self = shift;
  my ($sql,$q,$nodelist,@r);

  $nodelist = join(',',@_);
  $sql = qq{ select v.id, b.name block, n_files, n_tested, n_ok,
             s.name status, t.name test, time_reported
             from t_status_block_verify v join t_dvs_status s on v.status = s.id
             join t_dps_block b on v.block = b.id
             join t_dvs_test t on v.test = t.id };
  if ( $nodelist ) { $sql .= " where node in ($nodelist) "; }
  $sql .= ' order by s.id, time_reported';

  $q = $self->execute_sql( $sql, () );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

  return \@r;
}

sub getDetailedTestResults
{
  my $self = shift;
  my $request = shift;
  my ($sql,$q,@r);

  $sql = qq{ select logical_name, name status from t_dps_file f
                join t_dvs_file_result r on f.id = r.fileid
                join t_dvs_status s on r.status = s.id
                where request = :request and status in
                 (select id from t_dvs_status where not
                                (name = 'OK' or name = 'None' ) )
		order by logical_name
           };

  $q = $self->execute_sql( $sql, ( ':request' => $request ) );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

  return \@r;
}

#-------------------------------------------------------------------------------
#return a hash with size and checksum keys for an lfn from TMDB
sub getTMDBFileStats
{
  my $self = shift;
  my $sql = qq {select logical_name, checksum, filesize from t_dps_file
                where logical_name like :filename };
  my $l = shift @_;
  my %p = ( ":filename" => $l );
  my $r = $self->select_hash( $sql, 'LOGICAL_NAME', %p );
  my $s;
  $s->{SIZE} = $r->{$l}->{FILESIZE};
  foreach ( split( '[,;#$%/\s]+', $r->{$l}->{CHECKSUM} ) )
  {
    my ($k,$v) = m%^\s*([^:]+):(\S+)\s*$%;
    $s->{$k} = $v;
  }
  return $s;
}

#-------------------------------------------------------------------------------
sub getLFNsFromBlock
{
  my $self = shift;
  my $sql = qq {select logical_name from t_dps_file where inblock in
	        (select id from t_dps_block where name like :block)};
  my %p = ( ":block" => @_ );
  my $r = $self->select_single( $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksFromLFN
{
  my $self = shift;
  my $sql = qq {select name from t_dps_block where id in
      (select inblock from t_dps_file where logical_name like :lfn )};
  my %p = ( ":lfn" => @_ );
  my $r = $self->select_single( $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getDatasetsFromBlock
{
  my $self = shift;
  my $sql = qq {select name from t_dps_dataset where id in
		(select dataset from t_dps_block where name like :block ) };
  my %p = ( ":block" => @_ );
  my $r = $self->select_single( $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksFromDataset
{
  my $self = shift;
  my $sql = qq {select name from t_dps_block where dataset in
                (select id from t_dps_dataset where name like :dataset ) };
  my %p = ( ":dataset" => @_ );
  my $r = $self->select_single( $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getLFNsFromWildCard
{
  my $self = shift;
  my $sql =
	qq {select logical_name from t_dps_file where logical_name like :lfn };
  my %p = ( ":lfn" => @_ );
  my $r = $self->select_single( $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksFromWildCard
{
  my $self = shift;
  my $sql = qq {select name from t_dps_block where name like :block_wild};
  my %p = ( ":block_wild" => @_ );
  my $r = $self->select_single( $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getDatasetFromWildCard
{
  my $self = shift;
  my $sql = qq {select name from t_dps_dataset where name like :dataset_wild };
  my %p = ( ":dataset_wild" => @_ );
  my $r = $self->select_single( $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBufferFromWildCard
{
  my $self = shift;
  my $sql =
	qq {select id, name, technology from t_adm_node where name like :node };
  my %p = ( ":node" => @_ );
  my $r = $self->select_hash( $sql, 'ID', %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksOnBufferFromWildCard
{
  my $self = shift;
  my $buffers = join(',',@{$self->{bufferIDs}});
  my $sql = qq {select name from t_dps_block b join t_dps_block_replica br
                on b.id = br.block where name like :block_wild and
                node in ($buffers)};
  my %p = ( ":block_wild" => @_ );
  my $r = $self->select_single( $sql, %p );

  return $r;
}

#-------------------------------------------------------------------------------
sub select_single
{
  my ( $self, $query, %param ) = @_;
  my ($q,@r);

  $q = $self->execute_sql( $query, %param );
  @r = map {$$_[0]} @{$q->fetchall_arrayref()};
  return \@r;
}

#-------------------------------------------------------------------------------
sub select_hash
{
  my ( $self, $query, $key, %param ) = @_;
  my ($q,$r);

  $q = $self->execute_sql( $query, %param );
  $r = $q->fetchall_hashref( $key );

  my %s;
  map { $s{$_} = $r->{$_}; delete $s{$_}{$key}; } keys %$r;
  return \%s;
}

#-------------------------------------------------------------------------------
sub execute_sql
{
  my ( $self, $query, %param ) = @_;
  my ($dbh,$q,$r);

# Try this for size: If I am an object with a DBH, assume that's the database
# handle to use. Otherwise, assume _I_ am the database handle!
  $dbh = $self->{DBH} ? $self->{DBH} : $self;

  if ( $query =~ m%\blike\b%i )
  {
    foreach ( keys %param ) { $param{$_} =~ s%_%\\_%g; }
    $query =~ s%like\s+(:[^\)\s]+)%like $1 escape '\\' %gi;
  }

  if ( $self->{DEBUG} )
  {
    print " ==> About to execute\n\"$query\"\nwith\n";
    foreach ( sort keys %param ) { print "  \"$_\" = \"$param{$_}\"\n"; }
    print "\n";
  }
  $q = &dbexec($self->{DBH}, $query, %param);
  return $q;
}

sub get_TDVS_Tests
{
  my ($self,$test) = @_;
  my $x = $self->getTable(qw/t_dvs_test NAME id name description/);
  return $x->{$test} if defined $test;
  return $x;
}

sub get_TDVS_Status
{
  my ($self,$status) = @_;
  my $x = $self->getTable(qw/t_dvs_status NAME id name description/);
  return $x->{$status} if defined $status;
  return $x;
}

sub getTable
{
  my ($self,$table,$key,@fields) = @_;

  $key = 'ID' unless $key;
  @fields=('*') unless @fields;
  if ( defined($self->{T_Cache}{$table}) ) { return $self->{T_Cache}{$table}; }
  my $sql = "select " . join(',',@fields) . " from $table";
  return $self->{T_Cache}{$table} = $self->select_hash( $sql, $key, () );
}

1;
