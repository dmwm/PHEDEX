----------------------------------------------------------------------
-- Drop all schema objects.

set serveroutput on size 100000
BEGIN
   -- Tables
   FOR o IN (SELECT table_name name FROM user_tables WHERE table_name like 'T_%') LOOP
      dbms_output.put_line ('Dropping table ' || o.name || ' with dependencies');
      execute immediate 'drop table ' || o.name || ' cascade constraints';
   END LOOP;

   -- Sequences
   FOR o IN (SELECT sequence_name name FROM user_sequences WHERE sequence_name like 'SEQ_%') LOOP
      dbms_output.put_line ('Dropping sequence ' || o.name);
      execute immediate 'drop sequence ' || o.name;
   END LOOP;

   -- Triggers
   FOR o IN (SELECT trigger_name name FROM user_triggers) LOOP
      dbms_output.put_line ('Dropping trigger ' || o.name);
      execute immediate 'drop trigger ' || o.name;
   END LOOP;

   -- Synonyms
   FOR o IN (SELECT synonym_name name FROM user_synonyms) LOOP
      dbms_output.put_line ('Dropping synonym ' || o.name);
      execute immediate 'drop synonym ' || o.name;
   END LOOP;
END;
/
