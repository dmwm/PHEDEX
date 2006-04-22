-- create nodes
insert into t_node (id,name) values (seq_node.nextval,'A');
insert into t_node (id,name) values (seq_node.nextval,'A_SPUR');
insert into t_node (id,name) values (seq_node.nextval,'B');
insert into t_node (id,name) values (seq_node.nextval,'B_SPUR');
insert into t_node (id,name) values (seq_node.nextval,'C');
insert into t_node (id,name) values (seq_node.nextval,'C_SPUR');
insert into t_node (id,name) values (seq_node.nextval,'D');
insert into t_node (id,name) values (seq_node.nextval,'D_SPUR');
insert into t_node (id,name) values (seq_node.nextval,'E');
insert into t_node (id,name) values (seq_node.nextval,'E_SPUR');

insert into t_link (id, from_node, to_node, distance, local_boost)
  select seq_link.nextval, n1.id, n2.id, 1, 1
  from t_node n1, t_node n2
  where (n1.name like '_' and n2.name = n1.name || '_SPUR')
     or (n2.name like '_' and n1.name = n2.name || '_SPUR');

insert into t_link (id, from_node, to_node, distance, local_boost)
  select seq_link.nextval, n1.id, n2.id, 1, 0
  from t_node n1, t_node n2
  where n1.name like '_' and n2.name like '_';

insert into t_link_share (link, priority, link_share)
  select id, 0, 7 from t_link;
insert into t_link_share (link, priority, link_share)
  select id, 1, 4 from t_link;
insert into t_link_share (link, priority, link_share)
  select id, 2, 1 from t_link;
insert into t_link_share (link, priority, link_share)
  select id, 3, 1 from t_link;

-- seed blocks
insert into t_dps_dbs (id,name,time_create)
  values (seq_dps_dbs.nextval,'TestDBS',0);
insert into t_dps_dataset (id,dbs,name,is_open,is_transient,time_create)
  values (seq_dps_dataset.nextval,seq_dps_dbs.currval,'TestDS','y','n',0);

-- seed subscriptions
insert into t_dps_subscription
  (dataset, destination, priority, is_move, is_transient, time_create)
  select ds.id, n.id, 1, 'n', 'n', 0
  from t_dps_dataset ds, t_node n;

commit;
