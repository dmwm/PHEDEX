-- Simple sqlplus script to
-- query the data volume by group, node kind,
-- acquistion era and data tier
set pagesize 0
set linesize 400
set feedback off
column sum_node_bytes format 9999999999999999999
column user_group format a30
column acquisition_era format a80
column datatier format a30
select
 sum(br.node_bytes) as sum_node_bytes, g.name as user_group, nd.kind as node,
 replace(replace(regexp_substr(regexp_substr(d.name, '/[^/]+', 1, 2),'[^\-]+\-'),'/'),'-') as acquisition_era,
 replace(regexp_substr(d.name, '/[^/]+', 1, 3),'/') as datatier 
 from t_dps_dataset d
 join t_dps_block b on b.dataset=d.id
 join t_dps_block_replica br on br.block=b.id
 join t_adm_group g on g.id=br.user_group
 join t_adm_node nd on nd.id=br.node
 where br.node_bytes!=0 and br.dest_bytes!=0
 group by g.name, nd.kind, replace(replace(regexp_substr(regexp_substr(d.name, '/[^/]+', 1, 2),'[^\-]+\-'),'/'),'-'), replace(regexp_substr(d.name, '/[^/]+', 1, 3),'/')
 order by 2, 3, 4, 5;
quit

