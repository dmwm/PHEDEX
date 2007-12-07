package PHEDEX::BlockMonitor::SQL;

=head1 NAME

PHEDEX::BlockMonitor::SQL - encapsulated SQL for the Block Monitor
Checking agent.

=head1 SYNOPSIS

This package simply bundles SQL statements into function calls.
It's not a true object package as such, and should be inherited from by
anything that needs its methods.

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,
L<PHEDEX::BlockMonitor::Core|PHEDEX::BlockMonitor::Core>.

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';

use Carp;

our @EXPORT = qw( );
our (%params);
%params = (
	  );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new(%params,@_);
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

#-------------------------------------------------------------------------------
sub getExistingReplicaInfo
{
  my ($self,%h) = @_;
  my ($sql,%p,@r,$q);

  $sql = qq { select br.block, br.node,
           	br.is_active, b.files, b.bytes, b.is_open,
           	br.dest_files, br.dest_bytes,
           	br.src_files, br.src_bytes,
           	br.node_files, br.node_bytes,
           	br.xfer_files, br.xfer_bytes
      	from t_dps_block_replica br
        	join t_dps_block b on b.id = br.block };
  if ( $h{MIN_BLOCK} || $h{ROW_LIMIT} ) { $sql .= ' where '; }
  if ( $h{MIN_BLOCK} )
  {
    $sql .= 'br.block >= :block';
    $p{':block'} = $h{MIN_BLOCK};
  }
  if ( $h{MIN_BLOCK} && $h{ROW_LIMIT} ) { $sql .= ' and '; }
  if ( $h{ROW_LIMIT} )
  {
	  $sql .= 'rownum <= :row_num';
    $p{':row_num'} = $h{ROW_LIMIT};
  }
  $sql .= ' for update of b.id order by block asc';
  $q = execute_sql( $self, $sql, %p );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
  if ( wantarray )
  {
    $h{MAX_BLOCK} = $r[-1]->{BLOCK};
    $h{N_BLOCKS}  = scalar @r;
    return ( \@r, \%h );
  }
  return \@r;
}

#-------------------------------------------------------------------------------
sub getDestFilesNBytes
{
  my ($self,$h) = @_;
  my ($sql,%p,@r,$q);

  $sql = qq{ select b.id block, s.destination node,
		    b.files dest_files,
		    b.bytes dest_bytes
      		from t_dps_subscription s
      		left join t_dps_dataset ds on ds.id = s.dataset
      		left join t_dps_block b on b.dataset = ds.id or s.block = b.id
      		where };
  if ( !$h->{MIN_BLOCK} && !$h->{MAX_BLOCK} ) { $sql .=' b.id is not null'; }
  if ( $h->{MIN_BLOCK} )
  {
    $sql .= ' b.id >= :min_block';
    $p{':min_block'} = $h->{MIN_BLOCK};
  }
  if ( $h->{MIN_BLOCK} && $h->{MAX_BLOCK} ) { $sql .= ' and '; }
  if ( $h->{MAX_BLOCK} )
  {
    $sql .= ' b.id < :max_block';
    $p{':max_block'} = $h->{MAX_BLOCK};
  }

  $q = execute_sql( $self, $sql, %p );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
  return \@r;
}

#-------------------------------------------------------------------------------
sub getSrcFilesNBytes
{
  my ($self,$h) = @_;
  my ($sql,%p,@r,$q);

  $sql = qq{ select f.inblock block, f.node,
		    count(f.id)     src_files,
		    sum(f.filesize) src_bytes
      		from t_dps_file f };
  if ( $h->{MIN_BLOCK} || $h->{MAX_BLOCK} ) { $sql .= ' where '; }
  if ( $h->{MIN_BLOCK} )
  {
    $sql .= 'f.inblock >= :min_block';
    $p{':min_block'} = $h->{MIN_BLOCK};
  }
  if ( $h->{MIN_BLOCK} && $h->{MAX_BLOCK} ) { $sql .= ' and '; }
  if ( $h->{MAX_BLOCK} )
  {
    $sql .= 'f.inblock < :max_block';
    $p{':max_block'} = $h->{MAX_BLOCK};
  }
  $sql .= ' group by f.inblock, f.node ';
  $q = execute_sql( $self, $sql, %p );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
  return \@r;
}

#-------------------------------------------------------------------------------
sub getNodeFilesNBytes
{
  my ($self,$h) = @_;
  my ($sql,%p,@r,$q);

  $sql = qq{ select f.inblock block, xr.node,
		    count(xr.fileid) node_files,
		    sum(f.filesize)  node_bytes
      		from t_xfer_replica xr
		join t_xfer_file f on f.id = xr.fileid };
  if ( $h->{MIN_BLOCK} || $h->{MAX_BLOCK} ) { $sql .= ' where '; }
  if ( $h->{MIN_BLOCK} )
  {
    $sql .= 'f.inblock >= :min_block';
    $p{':min_block'} = $h->{MIN_BLOCK};
  }
  if ( $h->{MIN_BLOCK} && $h->{MAX_BLOCK} ) { $sql .= ' and '; }
  if ( $h->{MAX_BLOCK} )
  {
    $sql .= 'f.inblock < :max_block';
    $p{':max_block'} = $h->{MAX_BLOCK};
  }
  $sql .= ' group by f.inblock, xr.node';
  $q = execute_sql( $self, $sql, %p );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
  return \@r;
}

#-------------------------------------------------------------------------------
sub getXferFilesNBytes
{
  my ($self,$h) = @_;
  my ($sql,%p,@r,$q);

  $sql = qq{ select f.inblock block, xt.to_node node,
		    count(xt.fileid) xfer_files,
		    sum(f.filesize)  xfer_bytes
      		from t_xfer_task xt
		join t_xfer_file f on f.id = xt.fileid };
  if ( $h->{MIN_BLOCK} || $h->{MAX_BLOCK} ) { $sql .= ' where '; }
  if ( $h->{MIN_BLOCK} )
  {
    $sql .= 'f.inblock >= :min_block';
    $p{':min_block'} = $h->{MIN_BLOCK};
  }
  if ( $h->{MIN_BLOCK} && $h->{MAX_BLOCK} ) { $sql .= ' and '; }
  if ( $h->{MAX_BLOCK} )
  {
    $sql .= 'f.inblock < :max_block';
    $p{':max_block'} = $h->{MAX_BLOCK};
  }
  $sql .= ' group by f.inblock, xt.to_node';
  $q = execute_sql( $self, $sql, %p );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
  return \@r;
}

#-------------------------------------------------------------------------------
sub removeBlockAtNode
{
  my ($self,$h) = @_;
  my ($sql,%p);

  $sql = qq{ delete from t_dps_block_replica
		where block = :block and node = :node};
  %p = ( ':block' => $h->{BLOCK}, ':node' => $h->{NODE} );
  return if exists $self->{DUMMY} && $self->{DUMMY};
  execute_sql( $self, $sql, %p );
}

#-------------------------------------------------------------------------------
sub updateBlockAtNode
{
  my ($self,%h) = @_;
  my ($sql,%p);

  $sql = qq{ update t_dps_block_replica
            set time_update = :now, is_active = 'y',
                dest_files = :dest_files, dest_bytes = :dest_bytes,
                src_files  = :src_files,  src_bytes  = :src_bytes,
                node_files = :node_files, node_bytes = :node_bytes,
                xfer_files = :xfer_files, xfer_bytes = :xfer_bytes
            where block = :block and node = :node };
  $h{NOW} = mytimeofday() unless $h{NOW};
  foreach ( keys %h ) { $p{ ':' . lc($_) } = $h{$_}; }

  return if exists $self->{DUMMY} && $self->{DUMMY};
  execute_sql( $self, $sql, %p );
}

#-------------------------------------------------------------------------------
sub createBlockAtNode
{
  my ($self,%h) = @_;
  my ($sql,%p);

  $sql = qq{ insert into t_dps_block_replica
        (time_create, time_update,
         block, node, is_active,
         dest_files, dest_bytes,
         src_files,  src_bytes,
         node_files, node_bytes,
         xfer_files, xfer_bytes)
         values (:now, :now,
                :block, :node, 'y',
                :dest_files, :dest_bytes,
                :src_files,  :src_bytes,
                :node_files, :node_bytes,
                :xfer_files, :xfer_bytes) };
  $h{NOW} = mytimeofday() unless $h{NOW};
  foreach ( keys %h ) { $p{ ':' . lc($_) } = $h{$_}; }

  return if exists $self->{DUMMY} && $self->{DUMMY};
  execute_sql( $self, $sql, %p );
}

1;
