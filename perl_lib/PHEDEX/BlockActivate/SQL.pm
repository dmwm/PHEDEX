package PHEDEX::BlockActivate::SQL;

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
sub getBlockReactivationCandidates
{
  my $self = shift;
  my %h = @_;
  my $now = $h{NOW};
  my ($sql,$q,@r);

  $sql = qq{ 
            select b.id, b.name, count(br.block) nreplica,
			 sum(decode(br.is_active,'y',1,0)) nactive,
                         sum(decode(br.node_files,0,1,0)) nempty
            from t_dps_block b
              join t_dps_block_replica br
                on br.block = b.id
            where exists (select bd.block
                          from t_dps_block_dest bd
                          where bd.block = b.id
                            and bd.state != 3)
               or exists (select bd.block
                          from t_dps_block_delete bd
                          where bd.block = b.id and bd.time_complete is null)
               or exists (select ba.block
                          from t_dps_block_activate ba
                          where ba.block = b.id
                            and ba.time_request <= :now
                            and (ba.time_until is null
                                 or ba.time_until >= :now))
               or exists (select fi.block
                          from t_dps_file_invalidate fi
                          where fi.block = b.id and fi.time_complete is null)
            group by b.id, b.name
           };

  $q = execute_sql( $self, $sql, ( ':now' => $now ) );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

  return \@r;
}

#-------------------------------------------------------------------------------
sub removeOldActivationRequests
{
  my $self = shift;
  my %h = @_;
  my $now = $h{NOW};
  my ($sql,$q,@r);

  $sql = qq{ 
            delete from t_dps_block_activate
            where time_request < :now
              and time_until is not null
              and time_until < :now};
  $q = execute_sql( $self, $sql, ( ':now' => $now ) );
}

#-------------------------------------------------------------------------------
sub getLockForUpdateWithCheck
{
  my $self = shift;
  my %h = @_;
  my $block = $h{ID};
  my ($sql,$q,%p,@r);

  $sql = qq{ select * from t_dps_block where id = :block for update };
  %p = ( ':block' => $block );
  $q = execute_sql( $self, $sql, %p );

  $sql = qq{
      select count(block) nreplica,
             sum(decode(br.is_active,'y',1,0)) nactive,
             sum(decode(br.node_files,0,1,0)) nempty
      from t_dps_block_replica br 
      join t_dps_block b on b.id = br.block
     where br.block = :block};
  my ($xnreplica, $xnactive, $xnempty) = execute_sql( $self, $sql, %p )->fetchrow();

  return ($xnreplica, $xnactive, $xnempty) if wantarray;
  foreach ( qw / NREPLICA NACTIVE NEMPTY / )
  {
    $self->Warn("lockForUpdateWithCheck: Explicit check requested but \"$_\" not given") unless defined $h{$_};
  }
  return 1 if ( $h{NREPLICA} == $xnreplica && $h{NACTIVE} == $xnactive && $h{NEMPTY} == $xnempty );

# I do not use $self->{DBH}->rollback() here to preserve procedural access
  execute_rollback( $self );
  return 0;
}

#-------------------------------------------------------------------------------
sub activateBlock
{
  my $self = shift;
  my %h = @_;
  my $block = $h{ID};
  my $now   = $h{NOW};
  my ($sql,$q,%p,@r);

  my ($stmt, $nfile) = execute_sql ($self, qq{
      insert into t_xfer_file
      (id, inblock, logical_name, checksum, filesize)
      (select id, inblock, logical_name, checksum, filesize
       from t_dps_file where inblock = :block)},
      ":block" => $block);

  my ($stmt2, $nreplica) = execute_sql ($self, qq{
      insert into t_xfer_replica
      (id, fileid, node, state, time_create, time_state)
      (select seq_xfer_replica.nextval, f.id, br.node,
              0, br.time_create, :now
       from t_dps_block_replica br
       join t_dps_block b on b.id = br.block
       join t_xfer_file f on f.inblock = br.block
       where br.block = :block
         and br.is_active = 'n'
         and br.node_files > 0 )},
       ":block" => $block, ":now" => $now);

  my ($stmt3, $nblock) = execute_sql ($self, qq{
      update t_dps_block_replica
      set is_active = 'y', time_update = :now
      where block = :block
        and is_active = 'n' },
      ":block" => $block, ":now" => $now);

  return ($nfile, $nreplica, $nblock);
}

1;
