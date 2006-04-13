-- create nodes
insert into t_node (id,name) values (0,'A');
insert into t_node (id,name) values (1,'B');
insert into t_node (id,name) values (2,'C');
insert into t_node (id,name) values (3,'D');
insert into t_node (id,name) values (4,'E');
insert into t_node (id,name) values (5,'A_SPUR');
insert into t_node (id,name) values (6,'B_SPUR');
insert into t_node (id,name) values (7,'C_SPUR');
insert into t_node (id,name) values (8,'D_SPUR');
insert into t_node (id,name) values (9,'E_SPUR');

insert into t_link (id,from_node,to_node,distance,local_boost)
  values(0,0,1,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(1,0,2,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(2,0,3,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(3,0,4,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(4,1,0,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(5,1,2,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(6,1,3,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(7,1,4,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(8,2,0,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(9,2,1,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(10,2,3,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(11,2,4,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(12,3,0,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(13,3,1,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(14,3,2,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(15,3,4,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(16,4,0,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(17,4,1,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(18,4,2,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(19,4,3,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(20,5,0,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(21,0,5,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(22,6,1,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(23,1,6,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(24,2,7,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(25,7,2,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(26,3,8,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(27,8,3,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(28,4,9,1,0);
insert into t_link (id,from_node,to_node,distance,local_boost)
  values(29,9,4,1,0);

insert into t_link_share (link,priority,link_share)
  values (0,1,1);
insert into t_link_share (link,priority,link_share)
  values (1,1,1);
insert into t_link_share (link,priority,link_share)
  values (2,1,1);
insert into t_link_share (link,priority,link_share)
  values (3,1,1);
insert into t_link_share (link,priority,link_share)
  values (4,1,1);
insert into t_link_share (link,priority,link_share)
  values (5,1,1);
insert into t_link_share (link,priority,link_share)
  values (6,1,1);
insert into t_link_share (link,priority,link_share)
  values (7,1,1);
insert into t_link_share (link,priority,link_share)
  values (8,1,1);
insert into t_link_share (link,priority,link_share)
  values (9,1,1);
insert into t_link_share (link,priority,link_share)
  values (10,1,1);
insert into t_link_share (link,priority,link_share)
  values (11,1,1);
insert into t_link_share (link,priority,link_share)
  values (12,1,1);
insert into t_link_share (link,priority,link_share)
  values (13,1,1);
insert into t_link_share (link,priority,link_share)
  values (14,1,1);
insert into t_link_share (link,priority,link_share)
  values (15,1,1);
insert into t_link_share (link,priority,link_share)
  values (16,1,1);
insert into t_link_share (link,priority,link_share)
  values (17,1,1);
insert into t_link_share (link,priority,link_share)
  values (18,1,1);
insert into t_link_share (link,priority,link_share)
  values (19,1,1);
insert into t_link_share (link,priority,link_share)
  values (20,1,1);
insert into t_link_share (link,priority,link_share)
  values (21,1,1);
insert into t_link_share (link,priority,link_share)
  values (22,1,1);
insert into t_link_share (link,priority,link_share)
  values (23,1,1);
insert into t_link_share (link,priority,link_share)
  values (24,1,1);
insert into t_link_share (link,priority,link_share)
  values (25,1,1);
insert into t_link_share (link,priority,link_share)
  values (26,1,1);
insert into t_link_share (link,priority,link_share)
  values (27,1,1);
insert into t_link_share (link,priority,link_share)
  values (28,1,1);
insert into t_link_share (link,priority,link_share)
  values (29,1,1);

-- FIXME: Seed protocol export/import information too

-- seed blocks
insert into t_dps_dbs (id,name,time_create) values (0,'TestDBS',0);
insert into t_dps_dataset (id,dbs,name,is_open,is_transient,time_create)
    values (0,0,'TestDS','y','n',0);

-- seed subscriptions
insert into t_dps_subscription (dataset,destination,priority,is_move,
    is_transient,time_create)
    values (0,0,0,'n','n',0);
insert into t_dps_subscription (dataset,destination,priority,is_move,
    is_transient,time_create)
    values (0,1,0,'n','n',0);
insert into t_dps_subscription (dataset,destination,priority,is_move,
    is_transient,time_create)
    values (0,2,0,'n','n',0);
insert into t_dps_subscription (dataset,destination,priority,is_move,
    is_transient,time_create)
    values (0,3,0,'n','n',0);
insert into t_dps_subscription (dataset,destination,priority,is_move,
    is_transient,time_create)
    values (0,4,0,'n','n',0);
insert into t_dps_subscription (dataset,destination,priority,is_move,
    is_transient,time_create)
    values (0,5,0,'n','n',0);
insert into t_dps_subscription (dataset,destination,priority,is_move,
    is_transient,time_create)
    values (0,6,0,'n','n',0);
insert into t_dps_subscription (dataset,destination,priority,is_move,
    is_transient,time_create)
    values (0,7,0,'n','n',0);
insert into t_dps_subscription (dataset,destination,priority,is_move,
    is_transient,time_create)
    values (0,8,0,'n','n',0);
insert into t_dps_subscription (dataset,destination,priority,is_move,
    is_transient,time_create)
    values (0,9,0,'n','n',0);


commit;
