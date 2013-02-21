/*

=pod

=head1 NAME

Topology - storage node description and transfer topology.

=head1 DESCRIPTION

The topology tables describe the transfer network, defining "nodes"
(location which can hold file replicas) and "links" (connections
between nodes over which files are transferred).

=head1 TABLES

=head2 t_adm_node

Represents a place that can hold a file replica.  Each node should be
independent from the other, i.e. adding/removing a replica from one
node should not require that a replica be added/removed from another
node for consistency.  This requires that nodes represent physically
separate resources.  Nodes are created by L<the NodeNew
utility|Utilities::NodeNew>.

=over

=item t_adm_node.id

Unique ID for the storage node.

=item t_adm_node.name

Name of the storage node.  (Note: twenty charcter limit is required in
order to use node names as part of partition identifiers in Oracle.)

=item t_adm_node.kind

The type of storage this node represents, allowed values are:

  Disk       Basic non-volotile storage area
  Buffer     Volotile storage area (may feature garbage collection)
  MSS        Mass Storage System: large, slow permanent storage area
             which typically requires associated Buffers for holding
             files for staging/migration

=item t_adm_node.technology

The technology used by this storage node.  Allowed values are dCache,
Castor, DPM, Disk, StoRM, BeStMan, Other.

=item t_adm_node.se_name

SRM storage element host name.

=item t_adm_node.capacity

WARNING: FUTURE/UNUSED.  The total storage capacity in bytes of this node.

=item t_adm_node.bandwidth_cap

WARNING: FUTURE/UNUSED.  The maximum incoming/outgoing bandwidth
allowed in bytes per second.

=back

=cut

*/

create table t_adm_node
  (id			integer		not null,
   name			varchar (20)	not null,
   kind			varchar (20)	not null,
   technology		varchar (20)	not null,
   se_name		varchar (80),
   capacity		integer,
--   bandwidth_cap	integer,
   --
   constraint pk_adm_node
     primary key (id),
   --
   constraint uq_adm_node_name
     unique (name),
   --
   constraint ck_adm_node_kind
     check (kind in ('Buffer', 'MSS', 'Disk')),
   --
   constraint ck_adm_node_technology
     check (technology in ('dCache', 'Castor', 'DPM', 'Disk', 'StoRM', 'BeStMan', 'Other')));

create sequence seq_adm_node;

/*

=pod

=head2 t_adm_link

Represents a connection between two storage nodes over which data may
be transferred.  Links are created by 
L<the LinkNew utility|Utilities::LinkNew>.

=over

=item t_adm_link.id

Unique ID for this link.  (Note: practically unused in foreign key
relationships)

=item t_adm_link.from_node

The starting point of this link, FK to L<t_adm_node.id>.

=item t_adm_link.to_node

The ending point of this link, FK to L<t_adm_node.id>.

=item t_adm_link.distance

An integer weight for this link.  Lower values make a link more
preferred for transfers.  Used as a starting point for directing
transfers over the network.

=item t_adm_link.is_local

y or n, whether the link is over a local area network.

=item t_adm_link.is_active

y or n, whether the link is allowed to be used for transfers.

=item t_adm_link.is_preferred

WARNING: FUTURE/UNUSED.  Unclear what the original intention of this
column was.  Possibly whether the link is preferred by the to_node as
a path for transfers over the others.

=item t_adm_link.bandwidth_cap

WARNING: FUTURE/UNUSED.  Maximum bandwidth in bytes per second allowed
over this link.

=back

=cut

*/


create table t_adm_link
  (id			integer		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   distance		integer		not null,
   is_local		char (1)	not null,
   is_active		char (1)	not null,
--   is_preferred		char (1)	not null,
--   bandwidth_cap	integer,
   --
   constraint pk_adm_link
     primary key (id),
   --
   constraint uq_adm_link_key
     unique (from_node, to_node),
   --
   constraint fk_adm_link_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_adm_link_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint ck_adm_link_local
     check (is_local in ('y', 'n')),
   --
   constraint ck_adm_link_active
     check (is_active in ('y', 'n')),
   --
   constraint ck_adm_link_preferred
     check (is_preferred in ('y', 'n')));

create sequence seq_adm_link;

create index ix_adm_link_to
  on t_adm_link (to_node);

/*

=pod

=head2 t_adm_share

WARNING: FUTURE/UNUSED.  Unclear what the intention of this table
was.  Possibly to implement a fair-share algorithm to balance storage
among a set of nodes, treating the set like a single destination for files.

=over

=item t_adm_share.node

=item t_adm_share.priority

=item t_adm_share.fair_share

=back

=cut

*/

-- create table t_adm_share
--   (node			integer		not null,
--    priority		integer		not null,
--    fair_share		integer		not null,
--    --
--    constraint pk_adm_share
--      primary key (node, priority),
--    --
--    constraint fk_adm_share_node
--      foreign key (node) references t_adm_node (id)
--      on delete cascade);

/*

=pod

=head2 t_adm_link_param

Statistics describing current link transfer peformance.  
Managed by L<PerfMonitor|PHEDEX::Monitoring::PerfMonitor::Agent>.

=over

=item t_adm_link_param.from_node

Starting point of link, FK to L<t_adm_node.id|t_adm_node>.

=item t_adm_link_param.to_node

Ending point of link, FK to L<t_adm_node.id|t_adm_node>.

=item t_adm_link_param.time_update

Time the statistics were calculated.

=item t_adm_link_param.time_span

Duration (in seconds) over which events determining these statistics
were collected.

=item t_adm_link_param.pend_bytes

The size in bytes of the pending transfer queue over this link at time_update.

=item t_adm_link_param.done_bytes

The volume in bytes of successful transfers completed within the time_span.

=item t_adm_link_param.try_bytes

The volume in bytes of attempted transfers within the time_span.

=item t_adm_link_param.xfer_rate

The average rate in bytes per second over the time_span.

=item t_adm_link_param.xfer_latency

The expected amount of time in seconds to transfer the current
transfer queue.

=back

=cut

*/

create table t_adm_link_param
  (from_node		integer		not null,
   to_node		integer		not null,
   time_update		float		not null,
   time_span		integer,
   pend_bytes		float,
   done_bytes		float,
   try_bytes		float,
   xfer_rate		float,
   xfer_latency		float,
   --
   constraint pk_adm_link_param
     primary key (from_node, to_node),
   --
   constraint fk_adm_link_param_from
     foreign key (from_node) references t_adm_node (id)
     on delete cascade,
   --
   constraint fk_adm_link_param_to
     foreign key (to_node) references t_adm_node (id)
     on delete cascade)
 --
 organization index;
