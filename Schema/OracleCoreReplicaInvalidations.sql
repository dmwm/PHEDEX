/*
=pod

=head1 NAME

Transfer - tables for storing the file-level transfer workflow

=head1 DESCRIPTION

The Transfer tables are those which are needed to define and keep
track of the file-level transfer workflow.  This includes which files
need to be transferred, through which path they should be transferred,
the state of a given file transfer, and the bookkeeping of a file
replica upon successful transfer.

Most of these tables are considered "hot", that means that the rows do
not last very long in the database and a great number of DML
operations occur on them.  They are generally not useful for monitoring
because of this, unless the monitoring must be at a very fine-grained
level.

=head1 TABLES

/*

=pod

=head2 t_xfer_invalidate

Represents an invalidation task; a file which should be invalidated from a
node.  Managed by L<FileInvalidate|PHEDEX::FileInvalidate::Agent>.

=over

=item t_xfer_invalidate.fileid

File to be invalidated, FK to
L<t_xfer_file.id|Schema::OracleCoreFile/t_xfer_file>.

=item t_xfer_invalidate.node

Node the file should be invalidated from, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_invalidate.time_request

Time the invalidation was requested.

=item t_xfer_invalidate.time_complete

Time the invalidation was completed.

=back

=cut

*/

create table t_xfer_invalidate
  (fileid		integer		not null,  -- for which file
   node			integer		not null,  -- at which node
   time_request		float		not null,  -- time at request
   time_complete	float,			   -- time at completed
   --
   constraint pk_xfer_invalidate
     primary key (fileid, node),
   --
   constraint fk_xfer_invalidate_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade,
   --
   constraint fk_xfer_invalidate_node
     foreign key (node) references t_adm_node (id)
     on delete cascade
  )
  enable row movement;

create index ix_xfer_invalidate_node
  on t_xfer_invalidate (node);

