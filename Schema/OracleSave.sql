----------------------------------------------------------------------
-- Rename all tables, constraints, indices, sequences and triggers.
-- All the object names are prefixed with letter "X" to move the old
-- schema out of the way of the new one.

set serveroutput on size 100000
BEGIN
   --------------------
   -- X-Tables
--
-- Do we drop all the X% tables first, just for fun?
--
--   FOR o IN
--     (SELECT table_name name FROM user_tables
--      WHERE table_name LIKE 'X%')
--   LOOP
--      dbms_output.put_line ('Dropping table ' || o.name);
--      execute immediate 'drop table ' || o.name;
--   END LOOP;

   -- Tables
   FOR o IN
     (SELECT table_name name FROM user_tables
      WHERE table_name NOT LIKE 'X%')
   LOOP
      dbms_output.put_line ('Renaming table ' || o.name);
--      execute immediate 'drop table X' || o.name;
      execute immediate
          'rename ' || o.name
	  || ' to X' || substr (o.name, 1, 29);
   END LOOP;

   --------------------
   -- Sequences
   FOR o IN
     (SELECT sequence_name name FROM user_sequences
      WHERE sequence_name NOT LIKE 'X%')
   LOOP
      dbms_output.put_line ('Renaming sequence ' || o.name);
      execute immediate
          'rename ' || o.name
	  || ' to X' || substr (o.name, 1, 29);
   END LOOP;

   --------------------
   -- Constraints
   FOR o IN
     (SELECT constraint_name name, table_name FROM user_constraints
      WHERE constraint_name NOT LIKE 'X%'
        AND constraint_name NOT LIKE 'SYS%')
   LOOP
      dbms_output.put_line ('Renaming constraint ' || o.name || ' [' || o.table_name || ']');
      execute immediate
          'alter table ' || o.table_name
	  || ' rename constraint ' || o.name
	  || ' to X' || substr (o.name, 1, 29);
   END LOOP;

   --------------------
   -- Indices
   FOR o IN
     (SELECT index_name name, table_name FROM user_indexes
      WHERE index_name NOT LIKE 'X%'
        AND index_name NOT LIKE 'SYS%')
   LOOP
      dbms_output.put_line ('Renaming index ' || o.name || ' [' || o.table_name || ']');
      execute immediate
          'alter index ' || o.name
	  || ' rename to X' || substr (o.name, 1, 29);
   END LOOP;

   --------------------
   -- Triggers
   FOR o IN
     (SELECT trigger_name name, table_name FROM user_triggers
      WHERE trigger_name NOT LIKE 'X%')
   LOOP
      dbms_output.put_line ('Renaming trigger ' || o.name || ' [' || o.table_name || ']');
      execute immediate
          'alter trigger ' || o.name
	  || ' rename to X' || substr (o.name, 1, 29);
   END LOOP;
END;
/
