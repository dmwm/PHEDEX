-- seed blocks
insert into t_dps_dbs (id,name,dls,time_create)
  values (seq_dps_dbs.nextval,'TestDBS','mysql://lxgate10.cern.ch:18081',0);
commit;
