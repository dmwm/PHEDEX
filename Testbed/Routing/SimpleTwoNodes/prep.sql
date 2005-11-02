delete from t_routing where to_node like 'Tim-%'
delete from t_routing where from_node like 'Tim-%'
delete from t_routing where gateway like 'Tim-%'
delete from t_agent_status where node like 'Tim-%'
delete from t_node_neighbour where node like 'Tim-%'
delete from t_node where name like 'Tim-%'
insert into t_node values ('Tim-A')
insert into t_node values ('Tim-B')
insert into t_node_neighbour values ('Tim-A','Tim-B',1)
insert into t_node_neighbour values ('Tim-B','Tim-A',1)
