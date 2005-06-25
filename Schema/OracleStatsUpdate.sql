----------------------------------------------------------------------
-- Update statistics on all tables and indices.

set serveroutput on size 100000
BEGIN
   dbms_stats.gather_schema_stats
      (ownname => user,
       options => 'GATHER AUTO',
       estimate_percent => dbms_stats.auto_sample_size,
       method_opt => 'for all columns size repeat',
       degree => 10,
       cascade => true);
END;
/
