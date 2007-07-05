----------------------------------------------------------------------
-- Duplicate all tables.
-- All the table names are prefixed with letter "X"

set serveroutput on size 100000
BEGIN
   --------------------
   -- Tables
   FOR o IN
     (SELECT table_name name FROM user_tables
      WHERE table_name NOT LIKE 'X%')
   LOOP
      dbms_output.put_line ('Duplicating table ' || o.name);
      execute immediate
          'create table X' || substr (o.name, 1, 29) ||
	  ' as select * from ' || substr (o.name, 1, 29);
   END LOOP;
END;
/
