----------------------------------------------------------------------
-- Update statistics on all tables and indices.

set serveroutput on size 100000
BEGIN
   -- dbms_stats.delete_schema_stats(ownname => user);
   dbms_stats.gather_schema_stats
      (ownname => user,
       options => 'GATHER AUTO',
       degree => 2,
       cascade => true,
       no_invalidate => false,
       force => true);
END;
/
