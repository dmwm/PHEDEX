insert into t_node (id,name) 
	(select seq_node.nextval,name from xt_node);

insert into t_link (id,from_node,to_node,distance,local_boost)
	(select seq_link.nextval,f.id,t.id,decode(nn.hops,1,1,0),0
		from xt_node_neighbour nn
		join t_node f
			on f.name = nn.node
		join t_node t
			on t.name = nn.neighbour);

insert into t_link_share (link,priority,link_share)
	(select id,1,1 from t_link);

commit;

insert into t_dps_dbs (id,name,time_create) values (0,'TestDBS',0);

insert into t_dps_dataset (id,name,dbs,is_open,is_transient,time_create)
	(select seq_dps_dataset.nextval,owner || '/' || dataset,0,'y','n',0
		from xt_block xb);

insert into t_dps_block (id,dataset,name,files,bytes,is_open,time_create)
	(select seq_dps_block.nextval,dd.id,dd.name,xb.files,xb.bytes,'y',0
		from xt_block xb
		join t_dps_dataset dd
			on dd.name = xb.name);

insert into t_dps_file (id,node,inblock,logical_name,checksum,filesize,time_create)
	(select seq_dps_file.nextval,n.id,db.id,xf.lfn,xf.checksum,xf.filesize,xf.timestamp
		from xt_file xf
		join t_dps_block db
			on db.name = xf.inblock
		join t_node n
			on n.name = xf.node);

commit;

insert into t_xfer_file (id,inblock,logical_name,checksum,filesize)
	(select id,inblock,logical_name,checksum,filesize
		from t_dps_file);

commit;

insert into t_xfer_replica (id,fileid,node,state,time_create,time_state)
	(select seq_xfer_replica.nextval,df.id,n.id,xrs.state,xrs.timestamp,xrs.state_timestamp
		from t_dps_file df
		join xt_file xf
			on df.logical_name = xf.lfn
		join xt_replica_state xrs
			on xf.guid = xrs.guid
		join t_node n
			on xrs.node = n.name);

commit;

insert into t_dps_subscription (dataset,destination,priority,is_move,is_transient,time_create)
	(select dd.id,n.id,0,'n','n',0
		from t_dps_dataset dd, t_node n);

commit;

delete from t_dps_subscription 
	where destination in (select id from t_node where name like '%Load%');

delete from t_dps_subscription 
	where destination in 
		(select id 
			from t_node 
			where name like '%ZIP%'
				or name like '%LCG%'
				or name like '%NCU%');

commit;

