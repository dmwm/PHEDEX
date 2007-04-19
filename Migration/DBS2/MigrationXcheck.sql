select ds.name dataset,
       b.name block,
       n.name replica_at, 
       xds.name old_dataset,
       xb.name old_block,
       xn.name old_replica_at
  from t_dps_dataset ds
       join t_dps_block b on b.dataset = b.id
  left join t_dps_block_replica br on br.block = b.id
  left join t_adm_node n on n.id = br.node
  left join t_migration_dataset_map mds on mds.new = ds.name
  left join t_migration_block_map mb on mb.new = b.name
  left join xt_dps_dataset xds on xds.name = mds.old
  left join xt_dps_block xb on xb.name = mb.old
  left join xt_dps_block_replica xbr on xbr.block = xb.id
  left join xt_adm_node xn on xn.id = xbr.node
order by dataset, block, replica_at
;
