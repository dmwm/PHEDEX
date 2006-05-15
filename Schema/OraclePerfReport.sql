----------------------------------------------------------------------
-- Dump database performance report.

set lines 100 pages 9000 define :
select snap_id, begin_interval_time from dba_hist_snapshot where instance_number=1 order by 1;
spool report.txt
select * from table(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_TEXT(194199460, 1, :begin_id, :end_id));
spool off
