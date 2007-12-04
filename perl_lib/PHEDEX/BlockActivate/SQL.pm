package PHEDEX::BlockActivate::SQL;

=head1 NAME

PHEDEX::BlockActivate::SQL - encapsulated SQL for the Block Activation
Checking agent.

=head1 SYNOPSIS

This package simply bundles SQL statements into function calls.
It's not a true object package as such, and should be inherited from by
anything that needs its methods.

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,
L<PHEDEX::BlockAvtivate::Core|PHEDEX::BlockAvtivate::Core>.

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';

use PHEDEX::Core::DB;
use PHEDEX::Core::Timing qw / mytimeofday /;
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
  my $self  = $class->SUPER::new(@_);

  my %args = (@_);
  map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
      } keys %params;
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
			 sum(decode(br.is_active,'y',1,0)) nactive
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
      select count(block), sum(decode(br.is_active,'y',1,0))
      from t_dps_block_replica br where br.block = :block};
  my ($xnreplica, $xnactive) = execute_sql( $self, $sql, %p )->fetchrow();

  return ($xnreplica, $xnactive) if wantarray;
  foreach ( qw / NREPLICA NACTIVE / )
  {
    warn "lockForUpdateWithCheck: Explicit check requested but \"$_\" not given\n" unless defined $h{$_};
  }
  return 1 if ( $h{NREPLICA} == $xnreplica && $h{NACTIVE} == $xnactive );

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
       join t_xfer_file f on f.inblock = br.block
       where br.block = :block)},
       ":block" => $block, ":now" => $now);

  execute_sql ($self, qq{
      update t_dps_block_replica
      set is_active = 'y', time_update = :now
      where block = :block},
      ":block" => $block, ":now" => $now);
}

1;
