----------------------------------------------------------------------
-- Drop all schema objects.

set serveroutput on size 100000
BEGIN
   -- Tables
   FOR o IN (SELECT table_name name FROM user_tables) LOOP
      dbms_output.put_line ('Dropping table ' || o.name || ' with dependencies');
      execute immediate 'drop table ' || o.name || ' cascade constraints';
   END LOOP;

   -- Sequences
   FOR o IN (SELECT sequence_name name FROM user_sequences) LOOP
      dbms_output.put_line ('Dropping sequence ' || o.name);
      execute immediate 'drop sequence ' || o.name;
   END LOOP;

   -- Triggers
   FOR o IN (SELECT trigger_name name FROM user_triggers) LOOP
      dbms_output.put_line ('Dropping trigger ' || o.name);
      execute immediate 'drop trigger ' || o.name;
   END LOOP;

  -- Functions
  FOR o IN (SELECT object_name FROM user_objects WHERE object_type = 'FUNCTION') LOOP
      dbms_output.put_line ('Dropping function ' || o.object_name);
      execute immediate 'drop function ' || o.object_name;
  END LOOP;

  -- Procedures
  FOR o IN (SELECT object_name FROM user_objects WHERE object_type = 'PROCEDURE') LOOP
      dbms_output.put_line ('Dropping procedure ' || o.object_name);
      execute immediate 'drop procedure ' || o.object_name;
  END LOOP;

  -- Types
  FOR o IN (SELECT object_name FROM user_objects WHERE object_type = 'TYPE') LOOP
      dbms_output.put_line ('Dropping type ' || o.object_name);
-- N.B. To force the drop, add the 'force' option
--    execute immediate 'drop type ' || o.object_name || ' force';
      execute immediate 'drop type ' || o.object_name;
  END LOOP;

   -- Synonyms
   FOR o IN (SELECT synonym_name name FROM user_synonyms) LOOP
      dbms_output.put_line ('Dropping synonym ' || o.name);
      execute immediate 'drop synonym ' || o.name;
   END LOOP;

   -- Views
   FOR o IN (SELECT view_name name FROM user_views) LOOP
      dbms_output.put_line ('Dropping view ' || o.name);
      execute immediate 'drop view ' || o.name;
   END LOOP;
END;
/
