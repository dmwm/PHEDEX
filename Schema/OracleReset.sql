----------------------------------------------------------------------
-- Req
drop sequence seq_request_id;
drop table t_request_dataspec;
drop table t_request_subscription;
drop table t_request_operation;
drop table t_request;

-- DSB
drop sequence seq_dsb_fileid;
drop sequence seq_dsb_dataset;
drop table t_dsb_dataset_availability;
drop table t_dsb_dataset_run_file;
drop table t_dsb_dataset_run;
drop table t_dsb_dataset;
drop table t_dsb_file_attributes;
drop table t_dsb_file;
drop table t_dsb_fileid;

----------------------------------------------------------------------
-- Info
drop table t_info_transfer_status;
drop table t_info_transfer_rate;
drop table t_info_file_size_overview;
drop table t_info_file_size_histogram;
drop table t_info_agent_status;
drop table t_info_subscriptions;
drop table t_info_replication_overview;
drop table t_info_replication_details;

----------------------------------------------------------------------
-- Flow
drop table t_subscription;
drop table t_block_replica;
drop table t_block;

----------------------------------------------------------------------
-- CoreTriggers
drop trigger new_transfer_state;
drop trigger update_transfer_state;

-- CoreTransfer
drop table t_destination;
drop table t_replica_state;
drop table t_transfer_state;

-- CorePerf
drop table t_transfer_history;
drop table t_transfer_summary;

-- CoreAgents
drop table t_agent_status;
drop table t_agent_message;
drop table t_agent;

-- CoreFiles
drop table t_file_attributes;
drop table t_file;

-- CoreTopo
drop table t_node_import;
drop table t_node_export;
drop table t_routing;
drop table t_node;
