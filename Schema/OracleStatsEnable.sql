----------------------------------------------------------------------
-- Enable monitoring on all tables and indices.
-- http://www.orafaq.com/faqdbapf.htm
-- http://www.idevelopment.info/data/Oracle/DBA_tips/Oracle8i_New_Features/ORA8i_15.shtml

set serveroutput on size 100000
set def &
DECLARE
   -- c integer := dbms_sql.open_cursor;
BEGIN
   -- FIXME: Doesn't work: dbms_stats.alter_schema_tab_monitoring (user, true);
   FOR t IN (SELECT table_name FROM user_tables
   	     WHERE table_name NOT LIKE 'X%'
	       AND monitoring != 'YES')
   LOOP
      dbms_output.put_line ('Enabling monitoring for table ' || t.table_name);
      -- dbms_sql.parse (c, 'alter table ' || t.table_name || ' monitoring', dbms_sql.native);
      -- dbms_sql.execute (c); dbms_sql.close_cursor (c);
      -- execute immediate 'lock table ' || t.table_name || ' in exclusive mode';
      execute immediate 'alter table ' || t.table_name || ' monitoring';
   END LOOP;

   FOR i IN (SELECT index_name FROM user_indexes
	     WHERE index_name NOT LIKE 'SYS%'
	       AND index_name NOT LIKE 'X%'
	       AND index_type NOT LIKE 'IOT%'
	       AND last_analyzed is null)
   LOOP
      dbms_output.put_line ('Enabling monitoring for index ' || i.index_name);
      execute immediate 'alter index ' || i.index_name || ' monitoring usage';
   END LOOP;
END;
/
