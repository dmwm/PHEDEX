package PHEDEX::BlockDBSPopulate::SQL;

=head1 NAME

PHEDEX::BlockDBSPopulate::SQL - encapsulated SQL for the Block DBS Populate agent.

=head1 SYNOPSIS

This package simply bundles SQL statements into function calls.
It's not a true object package as such, and should be inherited from by
anything that needs its methods.

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';

our %params =
	(
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(%params,@_);
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

# Pick up ready blocks from database and inform downstream agents.
sub getCompleted
{
  my ($self,$node_filter,%p) = @_;
  my ($sql,$q,@r);

  $sql = qq{ select dbs.name dbs_name,
                   ds.name dataset_name,
	           b.name block_name,
	           b.id block_id,
	           n.name node_name,
	           n.id node_id,
		   n.se_name se_name, 
                   'migrateBlock' command
	    from t_dps_block_replica br
	      join t_dps_block b on b.id = br.block
	      join t_dps_dataset ds on ds.id = b.dataset
	      join t_dps_dbs dbs on dbs.id = ds.dbs
	      join t_adm_node n on n.id = br.node
	    where } . $node_filter .
         qq { and b.is_open = 'n'
	      and br.dest_files = b.files
	      and br.node_files = b.files
	      and n.se_name is not null };
  $q = execute_sql( $self, $sql, %p );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
  return \@r;
}


sub getDeleted
{
  my ($self,$node_filter,%p) = @_;
  my ($sql,$q,@r);

  $sql =  qq{
	    select dbs.name dbs_name,
	           ds.name dataset_name,
	           b.name block_name,
	           b.id block_id,
	           n.name node_name,
	           n.id node_id,
		   n.se_name se_name,
                   'deleteBlock' command
	    from t_dps_block_delete bd
	      join t_dps_block b on b.id = bd.block
	      join t_dps_dataset ds on ds.id = b.dataset
	      join t_dps_dbs dbs on dbs.id = ds.dbs
	      join t_adm_node n on n.id = bd.node
	    where } . $node_filter .
         qq { and b.is_open = 'n'
	      and bd.time_complete is not null
	      and n.se_name is not null};
  $q = execute_sql( $self, $sql, %p );
  while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }
  return \@r;
}

1;
