-- PhEDEx ORACLE triggers.
-- REQUIRES: OracleCorePerf.sql

----------------------------------------------------------------------
-- Add trigger to monitor changes to t_transfer_state and log entries
-- to t_transfer_history and t_transfer_summary.

create or replace trigger new_transfer_state
  after insert on t_transfer_state
  for each row
  begin
    insert into t_transfer_history
      (timestamp, guid,
       from_node, from_old_state, from_new_state,
       to_node, to_old_state, to_new_state)
      values
      (:new.to_timestamp, :new.guid,
       :new.from_node, null, :new.from_state,
       :new.to_node, null, :new.to_state);
  end;
/

create or replace trigger update_transfer_state
  after update of from_state, to_state on t_transfer_state
  for each row
  begin
    insert into t_transfer_history
      (timestamp, guid,
       from_node, from_old_state, from_new_state,
       to_node, to_old_state, to_new_state)
      values
      (case when :new.to_timestamp > :new.from_timestamp then
	:new.to_timestamp else :new.from_timestamp end, :old.guid,
       :old.from_node, :old.from_state, :new.from_state,
       :old.to_node, :old.to_state, :new.to_state);
  end;
/

show errors
