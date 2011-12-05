/*

=pod

=head1 NAME

Status - PhEDEx snapshot and historical statics, and logs

=head1 DESCRIPTION

Status tables come in three general types: snapshot tables, history
tables, and log tables.

Snapshot tables begin with C<t_status_> and describe some aspect of
the system at a single point in time, which is approximately the
present.  These tables are used to efficiently present aggregate
statistics to the user, for example via the web site.

History tables begin with C<t_history_> and contain time-ordered
statistics which should be saved forever.  These tables are used to
generate time-based plots of system, node, or link behavior.

Snapshot and history tables contain data-anonymous statistics.  They
describe counts of files or bytes, but not which files, blocks, or
datasets the statistics refer to.

Log table begin with C<t_log_> and contain more detailed statistics
that are identified by some data item as well as a timestamp.  Both
time-ordered and snapshot-type data can be derieved from these.

=head1 TABLES

=head2 t_status_block_request

This status table contains file and byte counts for requests for
transfer -- files allocated by the
L<FileRouter|PHEDEX::Infrastructure::FileRouter::Agent> for routing.
This data is aggregated by block and destination node from 
L<t_xfer_request|Schema::OracleCoreTransfer/t_xfer_request>.

=over

=item t_status_block_request.time_update

L<Time|Schema::Schema/Timestamp Columns> this data was gathered.

=item t_status_block_request.destination

Destination node, FK to
L<t_adm_node.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_status_block_request.block

Block ID, FK to
L<t_dps_block.id|Schema::OracleCoreTopo/t_adm_node.id>.

=item t_status_block_request.priority

Priority of the queue, see 
L<Schema::Schema/priority (Node-level)>.

=item t_status_block_request.is_custodial

Whether the requests are for custodial copies of the data.

=item t_status_block_request.state

The request state, see
L<t_xfer_request.state|Schema::OracleCoreTransfer/t_xfer_request.state>.

=item t_status_block_request.request_files

Number of files requested for transfer.

=item t_status_block_request.request_bytes

Number of bytes requested for transfer.

=item t_status_block_request.xfer_attempts

Total number of transfer attempts for all file requests for this block.

=item t_status_block_request.time_request

L<Time|Schema::Schema/Timestamp Columns> when the first request for a file
in this block was created.

=back

=cut

*/

 create table t_status_block_request
  (time_update		float		not null,
   destination		integer		not null,
   block		integer		not null,
   priority		integer		not null,
   is_custodial		char (1)	not null,
   state		integer		not null,
   request_files	integer		not null,
   request_bytes	integer		not null,
   xfer_attempts	integer		not null,
   time_request		integer		not null,
   --
   constraint pk_status_block_request
     primary key (destination, block, priority, is_custodial, state),
   --
   constraint fk_status_block_request_dest
     foreign key (destination) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_status_block_request_block
     foreign key (block) references t_dps_block (id)
     on delete cascade,
   --
   constraint ck_status_block_request_cust
     check (is_custodial in ('y', 'n'))
  );

 create index ix_status_block_request_dest
  on t_status_block_request (destination);

 create index ix_status_block_request_block
  on t_status_block_request (block);
