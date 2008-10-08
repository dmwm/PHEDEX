set scan off;

/* View of complete block replicas in the global DBS.
   This view is shared with the DBS schema in order to allow the
   Discovery Page and the DBS command-line tools to access information
   about block replica location.
 */
create or replace view v_dbs_block_replica as
select distinct b.name block_name,
                n.se_name se_name
  from t_dps_block_replica br
  join t_dps_block b on b.id = br.block
  join t_dps_dataset ds on ds.id = b.dataset
  join t_dps_dbs dbs on dbs.id = ds.dbs
  join t_adm_node n on n.id = br.node
 where b.is_open = 'n'
   and br.node_files != 0
   and br.node_files = b.files
   and n.se_name is not null
   and dbs.name = 'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet'
;

/* Grant necessary permissions to DBS accounts 
   TODO:  handle in OraclePrivs.sh ? */
-- grant select on v_dbs_block_replica to cms_dbs_prod_local_05 with grant option;
-- grant select on v_dbs_block_replica to cms_dbs_prod_local_05_reader;
-- grant select on v_dbs_block_replica to cms_dbs_prod_local_05_writer;
-- grant select on v_dbs_block_replica to cms_dbs_prod_local_05_admin;
