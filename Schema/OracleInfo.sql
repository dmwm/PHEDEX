create table t_info_transfer_status
	(update_stamp		integer		not null,
	 node			varchar (20)	not null,
	 snap_rfiles		integer		not null,
	 snap_tfiles		integer		not null,
	 snap_max_time		integer		not null,
	 n_files		integer		not null,
	 sz_files		integer		not null,
	 n_onsite		integer		not null,
	 sz_onsite		integer		not null,
	 n_staged		integer		not null,
	 sz_staged		integer		not null,
	 n_available		integer		not null,
	 sz_available		integer		not null,
	 n_in_transfer		integer		not null,
	 sz_in_transfer		integer		not null,
	 n_wanted		integer		not null,
	 sz_wanted		integer		not null,
	 n_pending		integer		not null,
	 sz_pending		integer		not null,
	 n_other		integer		not null,
	 sz_other		integer		not null,
	 primary key		(node),
	 foreign key		(node) references t_nodes (node_name));
create table t_info_transfer_rate
	(update_stamp		integer		not null,
	 time_span		varchar(20)	not null,
	 info_type		char(1)		not null,
	 from_node		varchar(20),
	 to_node		varchar(20),
	 n_total		integer		not null,
	 sz_total		integer		not null,
	 time_total		integer		not null,
	 bps_total		real		not null,
	 bps_average		real		not null,
	 bps_min		real		not null,
	 bps_max		real		not null);


create table t_info_file_size_overview
	(update_stamp		integer		not null,
	 n_files		integer		not null,
	 sz_total		integer		not null,
	 sz_min			integer		not null,
	 sz_max			integer		not null,
	 sz_mean		integer		not null,
	 sz_median		integer		not null);
create table t_info_file_size_histogram
	(update_stamp		integer		not null,
	 bin_low		integer		not null,
	 bin_width		integer		not null,
	 n_total		integer		not null,
	 sz_total		integer		not null);

create table t_info_drop_status
	(update_stamp		integer		not null,
	 site			varchar(20)	not null,
         host			varchar(30)	not null,
	 agent			varchar(20)	not null,
	 worker			varchar(20)	not null,
	 pid			integer		not null,
	 live			char(1)		not null,
	 state			varchar(20)	not null,
	 value			integer		not null);

create table t_info_subscriptions
	(update_stamp		integer		not null,
	 dataset		varchar(1000)	not null,
	 destination		varchar(20),
	 n_files		integer		not null,
	 sz_files		integer		not null,
	 n_files_at_dest	integer		not null,
	 sz_files_at_dest	integer		not null);

create table t_info_replication_overview
	(update_stamp		integer		not null,
	 dataset		varchar(1000)	not null,
	 owner			varchar(1000)	not null,
	 n_runs			integer		not null,
	 n_files		integer		not null,
	 sz_files		integer		not null);
create table t_info_replication_details
	(update_stamp		integer		not null,
	 dataset		varchar(1000)	not null,
	 owner			varchar(1000)	not null,
	 node			varchar(20)	not null,
	 n_files		integer		not null,
	 sz_files		integer		not null);

grant select on t_info_transfer_status		to cms_transfermgmt_reader;
grant select on t_info_transfer_rate		to cms_transfermgmt_reader;
grant select on t_info_file_size_overview	to cms_transfermgmt_reader;
grant select on t_info_file_size_histogram	to cms_transfermgmt_reader;
grant select on t_info_drop_status		to cms_transfermgmt_reader;
grant select on t_info_subscriptions		to cms_transfermgmt_reader;
grant select on t_info_replication_overview	to cms_transfermgmt_reader;
grant select on t_info_replication_details	to cms_transfermgmt_reader;
grant alter, delete, insert, select, update on t_info_transfer_status
   to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_info_transfer_rate
   to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_info_file_size_overview
   to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_info_file_size_histogram
   to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_info_drop_status
   to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_info_subscriptions
   to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_info_replication_overview
   to cms_transfermgmt_writer;
grant alter, delete, insert, select, update on t_info_replication_details
   to cms_transfermgmt_writer;

-- as cms_transfermgmt_reader and cms_transfermgmt_writer
create synonym t_info_transfer_status for cms_transfermgmt.t_info_transfer_status;
create synonym t_info_transfer_rate for cms_transfermgmt.t_info_transfer_rate;
create synonym t_info_file_size_overview for cms_transfermgmt.t_info_file_size_overview;
create synonym t_info_file_size_histogram for cms_transfermgmt.t_info_file_size_histogram;
create synonym t_info_drop_status for cms_transfermgmt.t_info_drop_status;
create synonym t_info_subscriptions for cms_transfermgmt.t_info_subscriptions;
create synonym t_info_replication_overview for cms_transfermgmt.t_info_replication_overview;
create synonym t_info_replication_details for cms_transfermgmt.t_info_replication_details;
