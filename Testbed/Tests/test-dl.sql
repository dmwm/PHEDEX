delete from t_replica_state where node = 'TEST_LAT' or node = 'castorgrid_mss';
delete from t_transfer_state where dest_node = 'TEST_LAT';
insert into t_replica_state (select guid, 'castorgrid_mss', 0, 0, 0, 0 from t_files_for_transfer);
insert into t_transfer_state (select guid, 'castorgrid_mss', 'TEST_LAT', 0, 0, 0, 0 from t_files_for_transfer);
