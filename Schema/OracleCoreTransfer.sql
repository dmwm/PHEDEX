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

=head2 t_xfer_catalogue

Stores the trivial file catalog, which translates logical file names
(LFNs) into physical file names (PFNs) via a set of regular
expression-based rules.

See
L<PHEDEX::Core::Catalogue|PHEDEX::Core::Catalogue> for more
information on the TFC.  Catalogues are uploaded by
L<FileExport|PHEDEX::File::Export::Agent> agents.

=over

=item t_xfer_catalogue.node

Node defining the catalogue, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_catalogue.rule_index

The ordered position of the rule.

=item t_xfer_catalogue.rule_type

The direction of the translation, 'lfn-to-pfn' or 'pfn-to-lfn'.

=item t_xfer_catalogue.protocol

The protocol of this rule chain, e.g. 'srm'.

=item t_xfer_catalogue.path_match

A regular expression which must match the input in order for the rule
to take effect.

=item t_xfer_catalogue.result_expr

The result of the rule, which may include references to capture
buffers from the path_match regular expression.

=item t_xfer_catalogue.chain

An (optional) protocol that this rule should be chained to after this rule.

=item t_xfer_catalogue.destination_match

Optional regular expression for a destination node name (in the case
of transfer tasks) which must match for this rule to take effect.

=item t_xfer_catalogue.is_custodial

Whether this rule applies to custodial data or not.

=item t_xfer_catalogue.space_token

The space token that should be applied should this rule match.

=item t_xfer_catalogue.time_update

Time this rule was written to the database.

=back

=cut

*/

create table t_xfer_catalogue
  (node			integer		not null,
   rule_index		integer		not null,
   rule_type		varchar (10)	not null,
   protocol		varchar (20)	not null,
   path_match		varchar (1000)	not null,
   result_expr		varchar (1000)	not null,
   chain		varchar (20),
   destination_match	varchar (40),
   is_custodial		char (1),
   space_token		varchar (64),
   time_update		float		not null,
   --
   constraint pk_xfer_catalogue
     primary key (node, rule_index),
   --
   constraint fk_xfer_catalogue_node
     foreign key (node) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_xfer_catalogue_type
     check (rule_type in ('lfn-to-pfn', 'pfn-to-lfn')),
   --
   constraint ck_xfer_catalogue_custodial
     check (is_custodial in ('y', 'n'))
  );


/*
=pod

=head2 t_xfer_source

Contains a list of links which are configured for outgoing transfers,
with the protocols they support.  Used by site agents to announce to
where they will serve transfers, and how.

This table is managed by L<FileExport|PHEDEX::File::Export::Agent>
agents.

=over

=item t_xfer_source.from_node

Source node of a file export, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_source.to_node

Destination node of a file export, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_source.protocols

Space-separated list of protocols supported.

=item t_xfer_source.time_update

Time at which the export link was last confirmed.

=back

=cut

*/

create table t_xfer_source
  (from_node		integer		not null,
   to_node		integer		not null,
   protocols		varchar (1000)	not null,
   time_update		float		not null,
   --
   constraint pk_xfer_source
     primary key (from_node, to_node),
   --
   constraint fk_xfer_source_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_source_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade
  );

create index ix_xfer_source_to
  on t_xfer_source (to_node);

/*
=pod

=head2 t_xfer_sink

Contains a list of links which are configured for incoming transfers,
with the protocols they support.  Used by site agents to announce from
where they will accept transfers, and how.

This table is managed by L<FileDownload|PHEDEX::File::Download::Agent>
agents.

=over

=item t_xfer_sink.from_node

Source node of a file import, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_sink.to_node

Destination node of a file import, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_sink.protocols

Space-separated list of protocols supported.

=item t_xfer_sink.time_update

Time at which the import link was last confirmed.

=back

=cut

*/

create table t_xfer_sink
  (from_node		integer		not null,
   to_node		integer		not null,
   protocols		varchar (1000)	not null,
   time_update		float		not null,
   --
   constraint pk_xfer_sink
     primary key (from_node, to_node),
   --
   constraint fk_xfer_sink_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_sink_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade
  );

create index ix_xfer_sink_to
  on t_xfer_sink (to_node);

/*
=pod

=head2 t_xfer_replica

Represents a file replica; a file at a node.  Replicas are created by
L<FilePump|PHEDEX::Infrastructure::FilePump::Agent>.

=over

=item t_xfer_replica.id

=item t_xfer_replica.node

Node the replica is at, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_replica.fileid

The file, FK to L<t_xfer_file.id|Schema::OracleCoreFile/t_xfer_file>.

=item t_xfer_replica.state

State of the replica:

  0 := not ready for export; may need staging
  1 := ready for export; staged

This state is managed by either
L<FilePump|PHEDEX::Infrastructure::FilePump::Agent> or
L<FileStager|PHEDEX::File::Stager::Agent>.

=item t_xfer_replica.time_create

Time this replica record was created.  (Note! Not neccissarily the time
the file was transferred to this node, especially in the case of
re-activated blocks.  See L<BlockActivate|PHEDEX::BlockActivate::Agent>.)

=item t_xfer_replica.time_state

Time the replica entered its current state.

=back

=cut

*/

create table t_xfer_replica
  (id			integer		not null,
   node			integer		not null,
   fileid		integer		not null,
   state		integer		not null,
   time_create		float		not null,
   time_state		float		not null,
   --
   constraint pk_xfer_replica
     primary key (id),
   --
   constraint uq_xfer_replica_key
     unique (node, fileid),
   --
   constraint fk_xfer_replica_node
     foreign key (node) references t_adm_node (id),
   --
   constraint fk_xfer_replica_fileid
     foreign key (fileid) references t_xfer_file (id)
  )
  partition by list (node)
    (partition node_dummy values (-1))
  enable row movement;

create sequence seq_xfer_replica;

create index ix_xfer_replica_fileid
  on t_xfer_replica (fileid);

/*

=pod

=head2 t_xfer_request

Represents a file request; a file that should be transferred to a
destination.  Filled and managed by
L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent>.

=over

=item t_xfer_request.fileid

The file, FK to L<t_xfer_file.id|Schema::OracleCoreFile/t_xfer_file>.

=item t_xfer_request.inblock

The block of the file, FK to
L<t_dps_block.id|Schema::OracleCoreBlock/t_dps_block>.

=item t_xfer_request.destination

The destination node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_request.priority

Request priority, see 
L<priority (Node-level)|Schema::Schema/"priority (Node-level)">.

=item t_xfer_request.is_custodial

y or n, whether this request is for custodial data.

=item t_xfer_request.state

State of the request, which takes the following values:

  -1 = Deactivated, just injected and awaiting activation
   0 = Active, valid transfer request
   1 = Deactivated, transfer failure
   2 = Deactivated, expiration
   3 = Deactivated, no path from any source
   4 = Deactivated, no source replicas

All non-zero values are "inactive" and are not being considered for
transfers at this time.

=item t_xfer_request.attempt

Counter for the number of attempts that have been made to complete
this request.

=item t_xfer_request.time_create

Time the request was created.

=item t_xfer_request.time_expire

Time the request expires.

=back

=cut

*/

create table t_xfer_request
  (fileid		integer		not null,
   inblock		integer		not null,
   destination		integer		not null,
   priority		integer		not null,
   is_custodial		char (1)	not null,
   state		integer		not null,
   attempt		integer		not null,
   time_create		float		not null,
   time_expire		float		not null,
   --
   constraint pk_xfer_request
     primary key (destination, fileid),
   --
   constraint fk_xfer_request_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade,
   --
   constraint fk_xfer_request_inblock
     foreign key (inblock) references t_dps_block (id)
     on delete cascade,
   --
   constraint fk_xfer_request_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_xfer_request_custodial
     check (is_custodial in ('y', 'n'))
  )
  partition by list (destination)
    (partition dest_dummy values (-1))
  enable row movement;

create index ix_xfer_request_inblock
  on t_xfer_request (inblock);

create index ix_xfer_request_fileid
  on t_xfer_request (fileid);

/*

=pod

=head2 t_xfer_path

A row in this table represents a single hop in the I<transfer path>.
The collection of hops from source to destination is the full transfer
path.  Filled and managed by
L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent>.

=over

=item t_xfer_path.destination

The destination of this transfer path.  FK to 
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_path.fileid

The the file for this transfer path.  FK to 
L<t_xfer_file.id|Schema::OracleCoreFile/t_xfer_file>.

=item t_xfer_path.hop

Iterator for the hops in a transfer path.  Hop 0 is attached to the
destination, and higher-order hops are closer to the src_node.

=item t_xfer_path.src_node

The source node for this transfer task; the original replica of the
file to be transferred. FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_path.from_node

The source node for this hop; the replica from which the file should
be transferred in this step.  FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_path.to_node

The destination node for this hop; the recepient of a transfer in this
step.  FK to L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_path.priority

Hop priority, see 
L<priority (Link-level)|Schema::Schema/"priority (Link-level)">.

=item t_xfer_path.is_local

0 or 1, whether the hop is over a local link.  (See
L<t_adm_link.is_local|Schema::OracleCoreTopo/t_adm_link.is_local>).

=item t_xfer_path.is_valid

0 or 1, whether the transfer path is valid.  Only valid transfer paths
will result in transfer tasks.  Invalid ones are written to the table
for monitoring and debugging purposes.

=item t_xfer_path.cost

The cost associated with this hop, in seconds of time expected to
transfer the file from from_node to to_node. 

=item t_xfer_path.total_cost

The total cost associated with this transfer path, in seconds of time
expected to transfer the file from src_node to destination.

=item t_xfer_path.penalty

WARNING: MISNAMED!  The link transfer rate for this hop which was used
when calculating the cost.

=item t_xfer_path.time_request

Time that the file request was made.  See L<t_xfer_request|t_xfer_request>.

=item t_xfer_path.time_confirm

Time that this transfer path was made.

=item t_xfer_path.time_expire

Time that this transfer path expires.

=back

=cut

*/

create table t_xfer_path
  (destination		integer		not null,  -- final destination
   fileid		integer		not null,  -- for which file
   hop			integer		not null,  -- hop from destination
   src_node		integer		not null,  -- original replica owner
   from_node		integer		not null,  -- from which node
   to_node		integer		not null,  -- to which node
   priority		integer		not null,  -- priority
   is_local		integer		not null,  -- local transfer priority
   is_valid		integer		not null,  -- route is acceptable
   cost			float		not null,  -- hop cost
   total_cost		float		not null,  -- total path cost
   penalty		float		not null,  -- path penalty
   time_request		float		not null,  -- request creation time
   time_confirm		float		not null,  -- last path build time
   time_expire		float		not null,  -- request expiry time
   --
   constraint pk_xfer_path
     primary key (to_node, fileid),
   --
   constraint uq_xfer_path_desthop
     unique (destination, fileid, hop),
   --
   constraint fk_xfer_path_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_path_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade,
   --
   constraint fk_xfer_path_src
     foreign key (src_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_path_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_path_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade
  )
  enable row movement;

create index ix_xfer_path_fileid
  on t_xfer_path (fileid);

create index ix_xfer_path_src
  on t_xfer_path (src_node);

create index ix_xfer_path_from
  on t_xfer_path (from_node);

create index ix_xfer_path_to
  on t_xfer_path (to_node);

/*

=pod

=head2 t_xfer_exclude

Contains a list of links and files over which transfer tasks should
B<not> be made.  Used to give PhEDEx time to re-evaluate coniditions
before re-issuing a failed transfer.  Filled by
L<FilePump|PHEDEX::Infrastructure::FilePump::Agent> and cleared by
L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent>.

=over

=item t_xfer_exclude.from_node

Source node of the exclusion, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_exclude.to_node

Destination node of the exclusion, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_exclude.fileid

File to be excluded, FK to
L<t_xfer_file.id|Schema::OracleCoreFile/t_xfer_file>.

=item t_xfer_exclude.time_request

Time the exclusion was requested.

=back

=cut

*/

create table t_xfer_exclude
  (from_node		integer		not null, -- xfer_path from_node
   to_node              integer         not null, -- xfer_path to_node
   fileid               integer         not null, -- xfer_path file id
   time_request		float		not null, -- time when suspension was requested
   --
   constraint pk_xfer_exclude
     primary key (from_node, to_node, fileid),
   --
   constraint fk_xfer_exclude_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_exclude_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_exclude_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade
  )
  enable row movement;

create index ix_xfer_exclude_to
  on t_xfer_exclude (to_node);

create index ix_xfer_exclude_fileid
  on t_xfer_exclude (fileid);

/*

=pod

=head2 t_xfer_task

Represents a transfer task; the command for site agents to perform a
transfer.

The state of a transfer task is represented in associated
tables L<t_xfer_task_export>, L<t_xfer_task_inxfer>,
L<t_xfer_task_done> and t_xfer_task_harvest>.  These states are in
separate tables because Oracles INSERT and DELETE performance is
superior to its UPDATE performance, and transfer tasks are the most
contentious and volitile quantity in PhEDEx.

This table is managed
by L<FileIssue|PHEDEX::Infrastructure::FileIssue::Agent> and
L<FilePump|PHEDEX::Infrastructure::FilePump::Agent>.

=over

=item t_xfer_task.id

Unique ID for the task.

=item t_xfer_task.fileid

File to be transferred by this task, FK to
L<t_xfer_file.id|Schema::OracleCoreFile/t_xfer_file>.

=item t_xfer_task.from_replica

Source replica to transfer in this task, FK to
L<t_xfer_replica.id|t_xfer_replica>.

=item t_xfer_task.priority

Task priority, see
L<priority (Link-level)|Schema::Schema/"priority (Link-level)">.

=item t_xfer_task.is_custodial

y or n, whether this task is a transfer into custodial storage.

=item t_xfer_task.rank

Order in which tasks should be completed.  This orders tasks when
L<priority|t_xfer_task.priority> is equal.

=item t_xfer_task.from_node

Source node of the transfer task, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_task.to_node

Destination node of the transfer task, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_task.time_expire

Time the task expires.

=item t_xfer_task.time_assign

Time the task was created.

=back

=cut

*/

/* FIXME: Consider using clustered table for t_xfer_task*, see
   Tom Kyte's Effective Oracle by Design, chapter 7. */
create table t_xfer_task
  (id			integer		not null, -- xfer id
   fileid		integer		not null, -- xref t_xfer_file
   from_replica		integer		not null, -- xref t_xfer_replica
   priority		integer		not null, -- (described above)
   is_custodial		char (1)	not null, -- custodial copy
   rank			integer		not null, -- current order rank
   from_node		integer		not null, -- node transfer is from
   to_node		integer		not null, -- node transfer is to
   time_expire		float		not null, -- time when expires
   time_assign		float		not null, -- time created
   --
   constraint pk_xfer_task
     primary key (id),
   --
   constraint uq_xfer_task_key
     unique (to_node, fileid),
   --
   constraint fk_xfer_task_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade,
   --
   constraint fk_xfer_task_replica
     foreign key (from_replica) references t_xfer_replica (id),
   --
   constraint fk_xfer_task_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_task_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade,
  --
   constraint ck_xfer_task_custodial
     check (is_custodial in ('y', 'n'))
  )
  partition by list (to_node)
    (partition to_dummy values (-1))
  enable row movement;

create sequence seq_xfer_task;

create index ix_xfer_task_from_node
  on t_xfer_task (from_node);

create index ix_xfer_task_from_file
  on t_xfer_task (from_node, fileid);

create index ix_xfer_task_to_node
  on t_xfer_task (to_node);

create index ix_xfer_task_from_replica
  on t_xfer_task (from_replica);

create index ix_xfer_task_fileid
  on t_xfer_task (fileid);

/*

=pod

=head2 t_xfer_task_export

Represents a transfer task for which the from_node is prepared to
serve the file.  For sites with tape storage, this usually means the
file has been recalled from tape and is on a disk buffer.

Managed by L<FileStager|PHEDEX::File::Stager::Agent> or
L<FilePump|PHEDEX::Infrastructure::FilePump::Agent>.

=over

=item t_xfer_task_export.task

The transfer task which is exported, FK to
L<t_xfer_task.id|t_xfer_task>.

=item t_xfer_task_export.time_update

The time the task was exported.

=back

=cut

*/

create table t_xfer_task_export
  (task			integer		not null,
   time_update		float		not null,
   --
   constraint pk_xfer_task_export
     primary key (task),
   --
   constraint fk_xfer_task_export_task
     foreign key (task) references t_xfer_task (id)
     on delete cascade
  )
  enable row movement;

/*

=pod

=head2 t_xfer_task_inxfer

Represents a task that has been acknowledged by the destination.

(WARNING: MISNAMED! This does not neccissarily mean that the task is
"in transfer", or that the transfer is currently taking place.  It
simply means the destination node has queued the transfer and it will
begin the transfer at the earliest opportunity)

Managed by L<FileDownload|PHEDEX::File::Download::Agent>.

=over

=item t_xfer_task_inxfer.task

The transfer task which has acknowledged, FK to
L<t_xfer_task.id|t_xfer_task>.

=item t_xfer_task_inxfer.from_pfn

The physical file name (PFN) which will be used at the source of this
transfer.

=item t_xfer_task_inxfer.to_pfn

The physical file name (PFN) which will be used at the destination of
this transfer.

=item t_xfer_task_inxfer.space_token

The space token which will be used at the destination of this
transfer.  (May be NULL).

=item t_xfer_task_inxfer.time_update

The time the task was acknowledged by the destination.

=back

=cut

*/

create table t_xfer_task_inxfer
  (task			integer		not null,
   from_pfn		varchar (1000)	not null, -- source pfn
   to_pfn		varchar (1000)	not null, -- destination pfn
   space_token		varchar (1000)		, -- destination space token
   time_update		float		not null,
   --
   constraint pk_xfer_task_inxfer
     primary key (task),
   --
   constraint fk_xfer_task_inxfer_task
     foreign key (task) references t_xfer_task (id)
     on delete cascade
  )
  enable row movement;

/*

=pod

=head2 t_xfer_task_done

Represents transfer tasks which have completed, and the result of the
transfer attempt.

Managed by L<FileDownload|PHEDEX::File::Download::Agent>.

=over

=item t_xfer_task_done.task

The transfer task that is done, FK to
L<t_xfer_task.id|t_xfer_task>.

=item t_xfer_task_done.report_code

Numerical result of the task, with the following general conventions:

   0  Successful transfer
 < 0  Unsuccessful transfer for PhEDEx-related reasons which are not
      considered a real failure.
 > 0  Unsuccessful transfer which are considered a failure.

See L<PHEDEX::Error::Constants|PHEDEX::Error::Constants> for more
details.  The value of this column is typically determined by the
xfer_code (below) and depends on the underlying commands used to
execute the transfer.

=item t_xfer_task_done.xfer_code

Numerical result of the command used to execute the transfer.  The
value of this column is determined by commands external to PhEDEx and
may or may not be a reliable indicator of success or failure.

=item t_xfer_task_done.time_xfer

The time the transfer attempt completed.

=item t_xfer_task_done.time_update

The time the completed transfer attempt was reported.

=back

=cut

*/

create table t_xfer_task_done
  (task			integer		not null,
   report_code		integer		not null,
   xfer_code		integer		not null,
   time_xfer		float		not null,
   time_update		float		not null,
   --
   constraint pk_xfer_task_done
     primary key (task),
   --
   constraint fk_xfer_task_done_task
     foreign key (task) references t_xfer_task (id)
     on delete cascade
  )
  enable row movement;

create sequence seq_xfer_done;

/*

=pod

=head2 t_xfer_task_harvest

Represents a transfer task which is done and is having its result
evaluated.  This is a bookkeeping device, and tasks are in this state
for a very short time.  Managed by
L<FilePump|PHEDEX::Infrastructure::FilePump::Agent>.

=over

=item t_xfer_task_harvest.task

The task which is being harvested, FK to
L<t_xfer_task.id|t_xfer_task>.

=back

=cut

*/

create table t_xfer_task_harvest
  (task			integer		not null,
   --
   constraint pk_xfer_task_harvest
     primary key (task),
   --
   constraint fk_xfer_task_harvest_task
     foreign key (task) references t_xfer_task (id)
     on delete cascade
  )
  enable row movement;

/*

=pod

=head2 t_xfer_error

Holds the details of failed transfers for a limited period of time.
Used for monitoring and debugging purposes.  Most column values are
coppied from L<t_xfer_task|t_xfer_task> and its state tables.  Managed
by L<FileDownload|PHEDEX::File::Download::Agent>.

=over

=item t_xfer_task.to_node

Destination node of the transfer task, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_task.from_node

Source node of the transfer task, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_task.fileid

File to be transferred by this task, FK to
L<t_xfer_file.id|Schema::OracleCoreFile/t_xfer_file>.

=item t_xfer_task.priority

Task priority, see
L<priority (Link-level)|Schema::Schema/"priority (Link-level)">.

=item t_xfer_task.is_custodial

y or n, whether this task is a transfer into custodial storage.

=item t_xfer_error.time_assign

See L<t_xfer_task.time_assign>.

=item t_xfer_error.time_expire

See L<t_xfer_task.time_expire>.

=item t_xfer_error.time_export

See L<t_xfer_task_export.time_update>.

=item t_xfer_error.time_inxfer

See L<t_xfer_task_inxfer.time_update>.

=item t_xfer_error.time_xfer

See L<t_xfer_task_done.time_xfer>.

=item t_xfer_error.time_done

See L<t_xfer_task_done.time_update>.

=item t_xfer_error.report_code

See L<t_xfer_task_done.report_code>.

=item t_xfer_error.xfer_code

See L<t_xfer_task_done.xfer_code>.

=item t_xfer_error.from_pfn

See L<t_xfer_task_inxfer.from_pfn>.

=item t_xfer_error.to_pfn

See L<t_xfer_task_inxfer.to_pfn>.

=item t_xfer_error.space_token

See L<t_xfer_task_inxfer.space_token>.

=item t_xfer_error.log_xfer

Full text ouput of the transfer command during the transfer attempt.

=item t_xfer_error.log_detail

Summarized result of the transfer attempt, attempting to capture the
important detail.

=item t_xfer_error.log_validate

Full text output of the validation command after the transfer attempt.

=back

=cut

*/

create table t_xfer_error
  (to_node		integer		not null, -- node transfer is to
   from_node		integer		not null, -- node transfer is from
   fileid		integer		not null, -- xref t_xfer_file
   priority		integer		not null, -- see at the top
   is_custodial		char (1)	not null, -- custodial copy
   time_assign		float		not null, -- time created
   time_expire		float		not null, -- time will expire
   time_export		float		not null, -- time exported
   time_inxfer		float		not null, -- time taken into transfer
   time_xfer		float		not null, -- time transfer started or -1
   time_done		float		not null, -- time completed
   report_code		integer		not null, -- final report code
   xfer_code		integer		not null, -- transfer report code
   from_pfn		varchar (1000)	not null, -- source pfn
   to_pfn		varchar (1000)	not null, -- destination pfn
   space_token		varchar (1000)		, -- destination space token
   log_xfer		clob,
   log_detail		clob,
   log_validate		clob,
   --
   constraint fk_xfer_export_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade,
   --
   constraint fk_xfer_export_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_xfer_export_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_xfer_error_custodial
     check (is_custodial in ('y', 'n'))
  )
  enable row movement;

create index ix_xfer_error_from_node
  on t_xfer_error (from_node);

create index ix_xfer_error_to_node
  on t_xfer_error (to_node);

create index ix_xfer_error_fileid
  on t_xfer_error (fileid);

/*

=pod

=head2 t_xfer_delete

Represents a deletion task; a file which should be deleted from a
node.  Managed by L<BlockDelete|PHEDEX::BlockDelete::Agent> and
L<FileRemove|PHEDEX::File::Remove::Agent>.

=over

=item t_xfer_delete.fileid

File to be deleted, FK to
L<t_xfer_file.id|Schema::OracleCoreFile/t_xfer_file>.

=item t_xfer_delete.node

Node the file should be deleted from, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node>.

=item t_xfer_delete.time_request

Time the deletion was requested.

=item t_xfer_delete.time_complete

Time the deletion was completed.

=back

=cut

*/

create table t_xfer_delete
  (fileid		integer		not null,  -- for which file
   node			integer		not null,  -- at which node
   time_request		float		not null,  -- time at request
   time_complete	float,			   -- time at completed
   --
   constraint pk_xfer_delete
     primary key (fileid, node),
   --
   constraint fk_xfer_delete_fileid
     foreign key (fileid) references t_xfer_file (id)
     on delete cascade,
   --
   constraint fk_xfer_delete_node
     foreign key (node) references t_adm_node (id)
     on delete cascade
  )
  enable row movement;

create index ix_xfer_delete_node
  on t_xfer_delete (node);


