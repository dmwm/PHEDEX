-- PhEDEx ORACLE schema for agent operations.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: OracleCoreTopo.sql

----------------------------------------------------------------------
-- Drop old tables

drop table t_info_transfer_status;
drop table t_info_transfer_rate;
drop table t_info_file_size_overview;
drop table t_info_file_size_histogram;
drop table t_info_drop_status;
drop table t_info_subscriptions;
drop table t_info_replication_overview;
drop table t_info_replication_details;

----------------------------------------------------------------------
-- Create new tables

create table t_info_transfer_status
  (timestamp		float		not null,
   node			varchar (20)	not null,
   snap_rfiles		integer		not null,
   snap_tfiles		integer		not null,
   snap_max_time	integer		not null,
   n_files		integer		not null,
   sz_files		integer		not null,
   n_onsite		integer		not null,
   sz_onsite		integer		not null,
   n_staged		integer		not null,
   sz_staged		integer		not null,
   n_available		integer		not null,
   sz_available		integer		not null,
   n_in_transfer	integer		not null,
   sz_in_transfer	integer		not null,
   n_wanted		integer		not null,
   sz_wanted		integer		not null,
   n_pending		integer		not null,
   sz_pending		integer		not null,
   n_other		integer		not null,
   sz_other		integer		not null);

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


create table t_info_drop_status
  (timestamp		float		not null,
   site			varchar (20)	not null,
   host			varchar (30)	not null,
   agent		varchar (20)	not null,
   worker		varchar (20)	not null,
   pid			integer		not null,
   live			char (1)	not null,
   state		varchar (20)	not null,
   value		integer		not null);


create table t_info_subscriptions
  (timestamp		float		not null,
   dataset		varchar (1000)	not null,
   destination		varchar (20),
   n_files		integer		not null,
   sz_files		integer		not null,
   n_files_at_dest	integer		not null,
   sz_files_at_dest	integer		not null);


create table t_info_replication_overview
  (timestamp		float		not null,
   dataset		varchar (1000)	not null,
   owner		varchar (1000)	not null,
   n_runs		integer		not null,
   n_files		integer		not null,
   sz_files		integer		not null);

create table t_info_replication_details
  (timestamp		float		not null,
   dataset		varchar (1000)	not null,
   owner		varchar (1000)	not null,
   node			varchar (20)	not null,
   n_files		integer		not null,
   sz_files		integer		not null);

----------------------------------------------------------------------
-- Add constraints

----------------------------------------------------------------------
-- Add indices

