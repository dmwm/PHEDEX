----------------------------------------------------------------------
-- Report block space usage distribution for all tables.
set lines 1000
set pages 1000

set serveroutput on size 100000
DECLARE
   unf   NUMBER;  unfb  NUMBER;
   fs1   NUMBER;  fs1b  NUMBER;
   fs2   NUMBER;  fs2b  NUMBER;
   fs3   NUMBER;  fs3b  NUMBER;
   fs4   NUMBER;  fs4b  NUMBER;
   full  NUMBER;  fullb NUMBER;
BEGIN
   dbms_output.put_line('-- Table block usage divided into six categories: unformatted (UF),');
   dbms_output.put_line('-- 0-25% full (Q1), 25-50% full (Q2), 50-75% full (Q3), 75-100% full (Q4)');
   dbms_output.put_line('-- and full (FL).  For each class reports number of blocks and kilobytes.');

   FOR user_tables_rec IN (SELECT table_name FROM user_tables) LOOP
      dbms_space.space_usage (USER, user_tables_rec.table_name, 'TABLE',
        unf, unfb, fs1, fs1b, fs2, fs2b, fs3, fs3b,
        fs4, fs4b, full, fullb);

      dbms_output.put_line(
        rpad(user_tables_rec.table_name, 30)
        || rpad (' UF=' || to_char(unf) || '/' || to_char(unfb/1024), 20)
        || rpad (' Q1=' || to_char(fs1) || '/' || to_char(fs1b/1024), 20)
        || rpad (' Q2=' || to_char(fs2) || '/' || to_char(fs2b/1024), 20)
        || rpad (' Q3=' || to_char(fs3) || '/' || to_char(fs3b/1024), 20)
        || rpad (' Q4=' || to_char(fs4) || '/' || to_char(fs4b/1024), 20)
        || rpad (' FL=' || to_char(full) || '/' || to_char(fullb/1024), 20));
   END LOOP;
END;
/

----------------------------------------------------------------------
-- Report free blocks in each table
set serveroutput on size 100000
DECLARE
   free NUMBER;
BEGIN
   dbms_output.put_line(rpad ('-- TABLE', 30) || 'FREE BLOCKS');

   FOR user_tables_rec IN (SELECT table_name FROM user_tables) LOOP
      dbms_space.free_blocks (USER, user_tables_rec.table_name, 'TABLE', 0, free);
      dbms_output.put_line(rpad(user_tables_rec.table_name, 30) || to_char(free));
   END LOOP;
END; 
/

----------------------------------------------------------------------
-- Report table growth trends (10g only)

select table_name, x.* from user_tables, table(select dbms_space.object_growth_trend (user, table_name, 'TABLE') from dual) x

----------------------------------------------------------------------
-- Report table space statistics.

set serveroutput on size 100000
DECLARE
   totblock   NUMBER; totbytes NUMBER;
   unusedbl   NUMBER; unusedby NUMBER;
   lu_ef_id   NUMBER; lu_eb_id NUMBER;
   lu_block   NUMBER; partname VARCHAR2(30);
   all_blocks NUMBER := 0;
   all_unused NUMBER := 0;
BEGIN
   FOR user_tables_rec IN (SELECT table_name FROM user_tables) LOOP
      dbms_space.unused_space(USER, user_tables_rec.table_name, 'TABLE',
         totblock, totbytes, unusedbl, unusedby, lu_ef_id, lu_eb_id,
         lu_block, partname);

      all_blocks := all_blocks + totblock;
      all_unused := all_unused + unusedbl;

      dbms_output.put_line('---------------------------');
      dbms_output.put_line(user_tables_rec.table_name);
      dbms_output.put_line('Total Blocks:              ' || TO_CHAR(totblock));
      dbms_output.put_line('Total Bytes:               ' || TO_CHAR(totbytes));
      dbms_output.put_line('Unused Blocks:             ' || TO_CHAR(unusedbl));
      dbms_output.put_line('Unused Bytes:              ' || TO_CHAR(unusedby));
      dbms_output.put_line('Last Used Extent File ID:  ' || TO_CHAR(lu_ef_id));
      dbms_output.put_line('Last Used Extent Block ID: ' || TO_CHAR(lu_eb_id));
      dbms_output.put_line('Last Used Block:           ' || TO_CHAR(lu_block));
   END LOOP;

   dbms_output.put_line('---------------------------');
   dbms_output.put_line('Total All Blocks:          ' || TO_CHAR(all_blocks));
   dbms_output.put_line('Unused All Blocks:         ' || TO_CHAR(all_unused));
   dbms_output.put_line('% Unused:                  ' || TO_CHAR(ROUND(all_unused/all_blocks*100)));
END;
/
