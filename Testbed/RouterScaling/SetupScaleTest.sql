-- seed blocks
insert into t_dps_dbs (id,name,dls,time_create)
  values (seq_dps_dbs.nextval,'TestDBS','mysql://lxgate10.cern.ch:18081',0);
insert into t_dps_dataset (id,dbs,name,is_open,is_transient,time_create)
  values (seq_dps_dataset.nextval,seq_dps_dbs.currval,'TestDS','y','n',0);


commit;
