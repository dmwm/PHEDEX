set scan off;

/* View of complete block replicas in the global DBS.
   This view is shared with the DBS schema in order to allow the
   Discovery Page and the DBS command-line tools to access information
   about block replica location.
 */
create or replace view v_dbs_block_replica as
select distinct b.name block_name,
		ds.name dataset_name,
		regexp_replace(regexp_replace(n.name, '_(Buffer|MSS|Export|Disk|Stage)$', ''),'T1_CH_CERN','T0_CH_CERN') site_name,
                n.se_name se_name
  from t_dps_block_replica br
  join t_dps_block b on b.id = br.block
  join t_dps_dataset ds on ds.id = b.dataset
  join t_dps_dbs dbs on dbs.id = ds.dbs
  join t_adm_node n on n.id = br.node
 where b.is_open = 'n'
   and br.node_files != 0
   and br.node_files = b.files
   and n.name not like 'X%'
   and n.se_name is not null
   and dbs.name = 'https://cmsdbsprod.cern.ch:8443/cms_dbs_prod_global_writer/servlet/DBSServlet'
;

create materialized view t_history_link_summary 
  refresh start with sysdate
  next sysdate+1 as 
select substr(gmtime(timebin), 0, 7) as timebin,
       trunc(sum(done_bytes)/power(1000,4), 2) as sum_gigabytes
 from t_history_link_events x
 join t_adm_node ns on ns.id = x.from_node
 join t_adm_node nd on nd.id = x.to_node
where nd.kind != 'MSS' and ns.kind != 'MSS'
 and timebin > 0
 group by substr(gmtime(timebin), 0, 7)
 order by 1
;
