-- A few time functions to make the operators life a little easier

-- Turn off variable substitution so that :00 isn't treated like a
-- bind variable!
set scan off;

-- returns a human-readable date if given a unix timestamp
create or replace function gmtime(unixtimestamp in integer) return varchar is
 result varchar(19);
begin
 result := TO_CHAR(TO_DATE('1970-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS') + numtodsinterval(unixtimestamp, 'SECOND'), 'YYYY-MM-DD HH24:MI:SS');
 return(result);
end gmtime;
/

grant execute on gmtime to public;

-- returns the current time as a unix timestamp
create or replace function now return number is
  result number;
begin
  result := (CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) - TO_DATE('1970-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')) * 24 *3600;
return(result);
end now;
/

grant execute on now to public;

-- returns the schema version
create or replace function schema_version return varchar is
  result varchar(20);
begin
  return('4.1.0');
end schema_version;
/

grant execute on schema_version to public;

-- adds a node and creates the required partitions in the xfer tables
-- access to this function should be strictly controlled, not public
create or replace procedure proc_add_node(name varchar2,
                                     kind varchar2,
                                     technology varchar2,
                                     se_name varchar2
                                     ) AS
  dml varchar(200);
  partition_name varchar(100);
  node_id number;
  begin
    insert into t_adm_node (id,name,kind,technology,se_name,capacity,bandwidth_cap)
                    values (seq_adm_node.nextval,name,kind,technology,se_name,1000,1000)
                    returning id into node_id;
    dbms_output.put_line('Inserted node ' || name || ' with id = ' || node_id);
    partition_name := 'node_' || lower(name);
    dml := ' add partition ' || partition_name || ' values (' || node_id || ')';
    execute immediate 'alter table t_xfer_replica' || dml;
    execute immediate 'alter table t_xfer_request' || dml;
    execute immediate 'alter table t_xfer_task'    || dml;
    commit;
    dbms_output.put_line('Created partitions and committed transaction');
  end;
/

-- delete a node and the corresponding partitions
-- access to this function should be strictly controlled, not public
create or replace procedure proc_delete_node(node varchar2) AS
  p_name varchar(100);
  begin
    delete from t_adm_node where name = node;
    dbms_output.put_line('Deleted node ' || node);
    p_name := 'NODE_' || upper(node);
    for p in (select table_name from user_tab_partitions
                      where partition_name = p_name
                      and table_name not like 'BIN$%') loop
      dbms_output.put_line('drop partition ' || p_name || ' from ' || p.table_name);
      execute immediate('alter table ' || p.table_name || ' drop partition ' || p_name);
    end loop;
    commit;
    dbms_output.put_line('Deleted partitions and committed transaction');
  end;
/

