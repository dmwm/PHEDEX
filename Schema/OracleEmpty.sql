----------------------------------------------------------------------
-- Drop all schema objects.

set serveroutput on size 100000
BEGIN
   -- Disable constraints: first foreign keys, then others
   FOR o IN (SELECT table_name, constraint_name FROM user_constraints
             WHERE constraint_name LIKE 'FK%') LOOP
      dbms_output.put_line ('Disabling constraint ' || o.constraint_name || ' on ' || o.table_name);
      execute immediate 'alter table ' || o.table_name
          || ' disable constraint ' || o.constraint_name;
   END LOOP;

   -- Tables
   FOR o IN (SELECT table_name name FROM user_tables) LOOP
      dbms_output.put_line ('Emptying table ' || o.name);
      execute immediate 'truncate table ' || o.name || ' drop storage';
   END LOOP;

   -- Re-enable constraints
   FOR o IN (SELECT table_name, constraint_name FROM user_constraints
             WHERE constraint_name LIKE 'FK%') LOOP
      dbms_output.put_line ('Enabling constraint ' || o.constraint_name || ' on ' || o.table_name);
      execute immediate 'alter table ' || o.table_name
          || ' enable constraint ' || o.constraint_name;
   END LOOP;
END;
/
