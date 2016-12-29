package PHEDEX::BlockDeactivate::SQL;

=head1 NAME

PHEDEX::BlockDeactivate::SQL - encapsulated SQL for the Block Deactivation
Checking agent.

=head1 SYNOPSIS

This package simply bundles SQL statements into function calls.
It's not a true object package as such, and should be inherited from by
anything that needs its methods.

=head1 DESCRIPTION

pending...

=head1 METHODS

=over

=item getBlockDeactivationCandidates( %h )

Takes a hash with keys LIMIT, BLOCK, and LOCK_FOR_UPDATE.

=over

=item *

LIMIT is the time_update cutoff to consider, and is obligatory.

=item *

BLOCK is an optional block-ID, to limit the selection. No wildcards allowed!

=item *

LOCK_FOR_UPDATE will, if true, cause the selected row(s) to be locked for
updates.

=back

The function returns a single hashref (if BLOCK was given) or an array of
hashrefs. Each hashref has the ID and NAME of the block that was selected.

=item nExpectedDeletions( %h )

Takes a hash with a BLOCK id, returns the sum of the node_files from
t_dps_block_replica for this block.

=item setBlockInactive( %h )

Takes a hash with a BLOCK id and an optional NOW key, a unix epoch time. NOW
defaults to the current time if not set. All block replicas have their is_active flag set
to 'n', and time_update set to NOW.

=item setBlockOpen( %h )

Takes a hash with a BLOCK id and an optional NOW key, a unix epoch time. NOW
defaults to the current time if not set. The block has its is_open flag set
to 'y', and time_update set to NOW.

=item deactivateReplicas( %h )

Takes a hash with a BLOCK id. Deletes files in that block from t_xfer_file,
and deletes that block from t_xfer_replica. Returns the number of blocks
it deletes.

=back

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,
L<PHEDEX::BlockActivate::Agent|PHEDEX::BlockActivate::Agent>.

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';

use PHEDEX::Core::Timing qw / mytimeofday /;
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
  return $self;
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
sub getBlockDeactivationCandidates
{
  my $self = shift;
  my %h = @_;
  my $limit = $h{LIMIT};
  my $block = $h{BLOCK};
  my $lock  = $h{LOCK_FOR_UPDATE};
  my $now = $h{NOW} || mytimeofday();
  my ($sql,%p,$q,@r);

  $self->Warn("No LIMIT defined in getBlockDeactivationCandidates") unless $limit;
  $sql = qq{ 
            select b.id, b.name name
            from t_dps_block b
            where b.is_open = 'n'
              and b.time_create < :limit
              and exists (select 1 from t_dps_block_replica br
                          where br.block = b.id)
              and (b.files, b.bytes, 0, 1, 'y') = all
                  (select br.node_files, br.node_bytes, br.xfer_files,
                          sign(:limit - br.time_update), br.is_active
                   from t_dps_block_replica br
                   where br.block = b.id)
              and not exists (select 1 from t_dps_block_delete bd
                               where bd.block = b.id
                                 and (bd.time_complete is null
				      or bd.time_complete > :limit))
              and not exists (select 1 from t_dps_block_activate ba
                               where ba.block = b.id
                                 and (ba.time_until is null
                                      or ba.time_until > :now))
              and not exists (select 1 from t_dps_file_invalidate fi
                               where fi.block = b.id
                                 and (fi.time_complete is null
                                      or fi.time_complete > :limit))                               
           };
  if ( $block )
  {
    $sql .= ' and b.id = :block';
    $p{':block'} = $block;
  }
  $sql .= ' order by b.files desc';
  if ( $lock ) { $sql .= ' for update of b.id'; }

  $p{':limit'} = $limit;
  $p{':now'} = $now;
  $q = execute_sql( $self, $sql, %p );

  if ( $block ) { return  $q->fetchrow_hashref(); }

  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
  return \@r;
}

#-------------------------------------------------------------------------------
sub nExpectedDeletions
{
  my $self = shift;
  my ($sql,%h,$id);
  %h = @_;
  $id = $h{BLOCK};

  $sql = qq{ select sum(node_files)
	     from t_dps_block_replica
	     where block = :block
	   };
  return execute_sql( $self, $sql, ( ':block' => $id ) )->fetchrow();
}

#-------------------------------------------------------------------------------
sub setBlockInactive
{
  my $self = shift;
  my ($sql,%h,%p,$id,$now,$db,$nb);
  %h = @_;
  $id = $h{BLOCK};
  $now = $h{NOW} || mytimeofday();

  $sql = qq{ update t_dps_block_replica set is_active = 'n', time_update = :now
	      where block = :block};
  %p = ( ':block' => $id,
	 ':now'   => $now );
  ($db,$nb) = execute_sql ($self, $sql, %p );
  return $nb;
}

#-------------------------------------------------------------------------------
sub setBlockOpen
{
  my $self = shift;
  my ($sql,%h,%p,$id,$now,$db,$nb);
  %h = @_;
  $id = $h{BLOCK};
  $now = $h{NOW} || mytimeofday();

  $sql = qq{ update t_dps_block set is_open = 'y', time_update = :now
		where id = :block };
  %p = ( ':block' => $id,
	 ':now'   => $now );
  ($db,$nb) = execute_sql ($self, $sql, %p );
  return $nb;
}

#-------------------------------------------------------------------------------
sub deactivateReplicas
{
  my $self = shift;
  my ($sql,%h,$id,$dr,$nr);
  %h = @_;
  $id = $h{BLOCK};

  $sql = qq{ delete from t_xfer_replica where fileid in
		(select id from t_xfer_file where inblock = :block)};
  ($dr,$nr) = execute_sql ($self, $sql, ( ':block' => $id ) );

  $sql = qq{ delete from t_xfer_file where inblock = :block };
  execute_sql ($self, $sql, ( ':block' => $id ) );
  return $nr;
}

1;
