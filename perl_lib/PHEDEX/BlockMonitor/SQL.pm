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
           	br.xfer_files, br.xfer_bytes,
	        br.is_custodial, br.user_group
      	      from t_dps_block_replica br
              join t_dps_block b on b.id = br.block };
  if ( exists $h{MIN_BLOCK} && exists $h{MAX_BLOCK} )
  {
      $sql .= 'where br.block >= :min_block and br.block <= :max_block';
      $p{':min_block'} = $h{MIN_BLOCK};
      $p{':max_block'} = $h{MAX_BLOCK};
  }
  $sql .= ' for update of b.id';
  $q = execute_sql( $self, $sql, %p );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
  if ( wantarray )
  {
      $h{N_REPLICAS}  = scalar @r;
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
		    b.bytes dest_bytes,
		    user_group, is_custodial
      		from t_dps_subscription s
      		join t_dps_block b on b.dataset = s.dataset or b.id = s.block
	    };
  if ( exists $h->{MIN_BLOCK} && exists $h->{MAX_BLOCK})
  {
    $sql .= ' where b.id >= :min_block and b.id <= :max_block';
    $p{':min_block'} = $h->{MIN_BLOCK};
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
  if ( exists $h->{MIN_BLOCK} && exists $h->{MAX_BLOCK})
  {
    $sql .= ' where f.inblock >= :min_block and f.inblock <= :max_block';
    $p{':min_block'} = $h->{MIN_BLOCK};
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
  if ( exists $h->{MIN_BLOCK} && exists $h->{MAX_BLOCK})
  {
    $sql .= ' where f.inblock >= :min_block and f.inblock <= :max_block';
    $p{':min_block'} = $h->{MIN_BLOCK};
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

  if ( exists $h->{MIN_BLOCK} && exists $h->{MAX_BLOCK})
  {
    $sql .= ' where f.inblock >= :min_block and f.inblock <= :max_block';
    $p{':min_block'} = $h->{MIN_BLOCK};
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
sub updateBlockFlags
{
  my ($self,%h) = @_;
  my ($sql,%p);

  my @b = qw(now block node 
	     is_custodial user_group);
  $sql = qq{ update t_dps_block_replica
            set time_update = :now, 
		is_custodial = :is_custodial, user_group = :user_group
            where block = :block and node = :node };
  $h{NOW} = mytimeofday() unless $h{NOW};
  foreach ( @b ) { $p{ ':' . $_ } = $h{uc($_)}; }

  return if exists $self->{DUMMY} && $self->{DUMMY};
  execute_sql( $self, $sql, %p );
}


#-------------------------------------------------------------------------------
sub updateBlockAtNode
{
  my ($self,%h) = @_;
  my ($sql,%p);

  my @b = qw(now block node 
	     dest_files dest_bytes src_files src_bytes 
	     node_files node_bytes xfer_files xfer_bytes);
  $sql = qq{ update t_dps_block_replica
            set time_update = :now, is_active = 'y',
                dest_files = :dest_files, dest_bytes = :dest_bytes,
                src_files  = :src_files,  src_bytes  = :src_bytes,
                node_files = :node_files, node_bytes = :node_bytes,
                xfer_files = :xfer_files, xfer_bytes = :xfer_bytes
            where block = :block and node = :node };
  $h{NOW} = mytimeofday() unless $h{NOW};
  foreach ( @b ) { $p{ ':' . $_ } = $h{uc($_)}; }

  return if exists $self->{DUMMY} && $self->{DUMMY};
  execute_sql( $self, $sql, %p );
}

#-------------------------------------------------------------------------------
sub createBlockAtNode
{
  my ($self,%h) = @_;
  my ($sql,%p);

  my @b = qw(now block node 
	     dest_files dest_bytes src_files src_bytes
	     node_files node_bytes xfer_files xfer_bytes
	     user_group is_custodial);
  $sql = qq{ insert into t_dps_block_replica
        (time_create, time_update,
         block, node, is_active,
         dest_files, dest_bytes,
         src_files,  src_bytes,
         node_files, node_bytes,
         xfer_files, xfer_bytes,
	 user_group, is_custodial)
         values (:now, :now,
                :block, :node, 'y',
                :dest_files, :dest_bytes,
                :src_files,  :src_bytes,
                :node_files, :node_bytes,
                :xfer_files, :xfer_bytes,
		:user_group, :is_custodial) };
  $h{NOW} = mytimeofday() unless $h{NOW};

  foreach ( @b ) { $p{ ':' . $_ } = $h{uc($_)}; }

# Sanity-check: look for missing keys. If user_group is missing, that's OK
  my @m;
  foreach ( @b ) { push @m,$_ unless ( exists($h{uc($_)}) || $_ eq 'user_group' ); }
  if ( @m )
  {
    $self->Alert('createBlockAtNode: missing keys ',join(' ,',sort @m),
	' in block ',join(', ', map { defined($p{$_}) ? "$_=$p{$_}" : "$_=" }
			   sort keys %p) );
  }

  if ( $self->{DEBUG} )
  {
    $self->Logmsg('createBlockAtNode: ',
		join(', ',
		  map { "$_=" . ( defined($p{$_}) ? $p{$_} : 'undef' ) }
		    sort keys %p) );
  }
  return if ( exists $self->{DUMMY} && $self->{DUMMY} );
  execute_sql( $self, $sql, %p );
}

1;
