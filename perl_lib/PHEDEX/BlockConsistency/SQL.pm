package PHEDEX::BlockConsistency::SQL;
#
# This package simply bundles SQL statements into function calls.
# It's not a true object package as such, and should be inherited from by
# anything that needs its methods.
#
use strict;
use warnings;
use base 'PHEDEX::Core::SQL';

use UtilsDB;
use Carp;

our @EXPORT = qw( );
our (%params);
%params = (
		DBH	=> undef,
	  );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(@_);

  my %args = (@_);
  map { $$self{$_} = $args{$_} } keys %params;
  bless $self, $class;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

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

1;
