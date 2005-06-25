----------------------------------------------------------------------
-- Drop old (as created by OracleSave.sql) schema objects.

set serveroutput on size 100000
BEGIN
   -- Tables
   FOR o IN (SELECT table_name name FROM user_tables WHERE table_name LIKE 'X%') LOOP
      dbms_output.put_line ('Dropping table ' || o.name || ' with dependencies');
      execute immediate 'drop table ' || o.name || ' cascade constraints';
   END LOOP;

   -- Sequences
   FOR o IN (SELECT sequence_name name FROM user_sequences WHERE sequence_name LIKE 'X%') LOOP
      dbms_output.put_line ('Dropping sequence ' || o.name);
      execute immediate 'drop sequence ' || o.name;
   END LOOP;

   -- Triggers
   FOR o IN (SELECT trigger_name name FROM user_triggers WHERE trigger_name LIKE 'X%') LOOP
      dbms_output.put_line ('Dropping trigger ' || o.name);
      execute immediate 'drop trigger ' || o.name;
   END LOOP;
END;
/
