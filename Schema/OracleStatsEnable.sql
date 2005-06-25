----------------------------------------------------------------------
-- Enable monitoring on all tables and indices.

set serveroutput on size 100000
DECLARE
   -- c integer;
BEGIN
   -- FIXME: Doesn't work: dbms_stats.alter_schema_tab_monitoring (user, true);
   -- c := dbms_sql.open_cursor;
   FOR t IN (SELECT table_name FROM user_tables) LOOP
      dbms_output.put_line ('Enabling monitoring for table ' || t.table_name);
      execute immediate 'alter table ' || t.table_name || ' monitoring';
      -- dbms_sql.parse (c, 'alter table ' || t.table_name || ' monitoring', dbms_sql.native);
      -- dbms_sql.execute (c); dbms_sql.close_cursor (c);
   END LOOP;

   FOR i IN (SELECT index_name FROM user_indexes where index_name not like 'SYS%') LOOP
      dbms_output.put_line ('Enabling monitoring for index ' || i.index_name);
      execute immediate 'alter index ' || i.index_name || ' monitoring usage';
      -- dbms_sql.parse (c, 'alter index ' || i.index_name || ' monitoring usage', dbms_sql.native);
      -- dbms_sql.execute (c); dbms_sql.close_cursor (c);
   END LOOP;
END;
/
