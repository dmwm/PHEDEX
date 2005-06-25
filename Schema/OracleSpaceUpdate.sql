----------------------------------------------------------------------
-- These statements compact space in the tables that undergo most heavy
-- insertion/deletion rates.  You will want to run this every once in a
-- while, especially when large changes have occurred, such as archiving
-- of transfer history, completion of significant file transfers, or the
-- deactivation of large numbers of file blocks.
--
-- Remember to update table statistics afterwards.
--
-- This stuff is Oracle 10g only.  For an explanation on how this could
-- perhaps be done in 91 via dbms_redefinition package, please see see
-- http://www.oracle-base.com/articles/9i/HighAvailabilityEnhancements9i.php


alter table t_transfer_history shrink space compact cascade;
alter table t_transfer_history shrink space cascade;

alter table t_replica_state shrink space compact cascade;
alter table t_replica_state shrink space cascade;

alter table t_transfer_state shrink space compact cascade;
alter table t_transfer_state shrink space cascade;

alter table t_transfer_completed shrink space compact cascade;
alter table t_transfer_completed shrink space cascade;
