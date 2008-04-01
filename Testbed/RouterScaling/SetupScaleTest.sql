-- seed blocks
insert into t_dps_dbs (id,name,dls,time_create)
  values (seq_dps_dbs.nextval,'TestDBS','unknown',0);
commit;
