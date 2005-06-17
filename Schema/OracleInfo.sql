-- PhEDEx ORACLE schema for agent operations.
-- NB: s/([ ])CMS_TRANSFERMGMT_INDX01/${1}INDX01/g for devdb
-- NB: s/([ ])INDX01/${1}CMS_TRANSFERMGMT_INDX01/g for cms
-- REQUIRES: OracleCoreTopo.sql

----------------------------------------------------------------------
-- Create new tables

create table t_info_transfer_status
  (timestamp		float		not null,
   node			varchar (20)	not null,
   dest_files		integer		not null,
   dest_bytes		integer		not null,
   node_files		integer		not null,
   node_bytes		integer		not null,
   xfer_files		integer		not null,
   xfer_bytes		integer		not null,
   expt_files		integer		not null,
   expt_bytes		integer		not null);

create table t_info_transfer_states
  (timestamp		float		not null,
   from_node		varchar (20)	not null,
   to_node		varchar (20)	not null,
   from_state		integer		not null,
   to_state		integer		not null,
   files		integer		not null,
   bytes		integer		not null);

create table t_info_replica_states
  (timestamp		float		not null,
   node			varchar (20)	not null,
   state		integer		not null,
   files		integer		not null,
   bytes		integer		not null);

create table t_info_transfer_rate
  (timestamp		float		not null,
   time_span		varchar (20)	not null,
   info_type		char (1)	not null,
   from_node		varchar (20),
   to_node		varchar (20),
   n_total		integer		not null,
   sz_total		integer		not null,
   time_total		float		not null,
   bps_total		float		not null,
   bps_average		float		not null,
   bps_min		float		not null,
   bps_max		float		not null);


create table t_info_file_size_overview
  (timestamp		float		not null,
   n_files		integer		not null,
   sz_total		integer		not null,
   sz_min		integer		not null,
   sz_max		integer		not null,
   sz_mean		integer		not null,
   sz_median		integer		not null);

create table t_info_file_size_histogram
  (timestamp		float		not null,
   bin_low		integer		not null,
   bin_width		integer		not null,
   n_total		integer		not null,
   sz_total		integer		not null);


create table t_info_agent_status
  (timestamp		float		not null,
   site			varchar (20)	not null,
   host			varchar (40)	not null,
   path			varchar (255)	not null,
   agent		varchar (20)	not null,
   worker		varchar (20)	not null,
   pid			integer		not null,
   live			char (1)	not null,
   state		varchar (20)	not null,
   value		integer		not null);


create table t_info_subscriptions
  (timestamp		float		not null,
   owner		varchar (100)	not null,
   dataset		varchar (100)	not null,
   destination		varchar (20),
   n_files		integer		not null,
   sz_files		integer		not null,
   n_files_at_dest	integer		not null,
   sz_files_at_dest	integer		not null);


create table t_info_replication_overview
  (timestamp		float		not null,
   owner		varchar (100)	not null,
   dataset		varchar (100)	not null,
   n_runs		integer		not null,
   n_files		integer		not null,
   sz_files		integer		not null);

create table t_info_replication_details
  (timestamp		float		not null,
   owner		varchar (100)	not null,
   dataset		varchar (100)	not null,
   node			varchar (20)	not null,
   n_files		integer		not null,
   sz_files		integer		not null);

----------------------------------------------------------------------
-- Add constraints

----------------------------------------------------------------------
-- Add indices

