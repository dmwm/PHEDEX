-- PhEDEx ORACLE triggers.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: OracleCorePerf.sql

----------------------------------------------------------------------
-- Add trigger to monitor changes to t_transfer_state and log entries
-- to t_transfer_history and t_transfer_summary.

create or replace trigger new_transfer_state
  after insert on t_transfer_state
  for each row
  declare
    epoch date := to_date ('1970-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS');
    now float := (systimestamp - epoch) * 86400;
  begin
    insert into t_transfer_history
      (timestamp, guid,
       from_node, from_old_state, from_new_state,
       to_node, to_old_state, to_new_state)
      values
      (now, :new.guid,
       :new.from_node, null, :new.from_state,
       :new.to_node, null, :new.to_state);

    insert into t_transfer_summary
      (guid, from_node, to_node,
       assigned, wanted, exported, started, completed,
       errors, inerror, last_error_entry)
      values
      (:new.guid, :new.from_node, :new.to_node,
       now, null, null, null, null,
       0, 0, null);
  end;

create or replace trigger update_transfer_state
  after update of from_state, to_state on t_transfer_state
  for each row
  declare
    epoch date := to_date ('1970-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS');
    now float := (systimestamp - epoch) * 86400;
  begin
    -- always log the change as such (including error states)
    insert into t_transfer_history
      (timestamp, guid,
       from_node, from_old_state, from_new_state,
       to_node, to_old_state, to_new_state)
      values
      (now, :old.guid,
       :old.from_node, :old.from_state, :new.from_state,
       :old.to_node, :old.to_state, :new.to_state);

    -- now log changes to the summary table columns for this file;
    -- we update only the last row in the table for this transfer in
    -- case the file is getting transferred several times

    -- update summary "wanted" when the file is marked wanted (to_state
    -- becomes 1) for the first time, including jumps over wanted state
    if :old.to_state < 1 and :new.to_state >= 1 and :new.to_state <= 3 then
      update t_transfer_summary set wanted = now
      where rowid = (select * from
		       (select rowid from t_transfer_summary
		        where guid = :old.guid
			  and from_node = :old.from_node
			  and to_node = :old.to_node
		        order by assigned desc)
		     where rownum = 1);
    end if;

    -- update summary "exported" when marked so the last time
    if :old.from_state < 1 and :new.from_state = 1 and :new.to_state < 2 then
      update t_transfer_summary set exported = now
      where rowid = (select * from
		       (select rowid from t_transfer_summary
		        where guid = :old.guid
			  and from_node = :old.from_node
			  and to_node = :old.to_node
		        order by assigned desc)
		     where rownum = 1);
    end if;

    -- update summary "started" when marked in transfer the last time
    if :old.to_state < 2 and :new.to_state >= 2 and :new.to_state <= 3 then
      update t_transfer_summary set started = now
      where rowid = (select * from
		       (select rowid from t_transfer_summary
		        where guid = :old.guid
			  and from_node = :old.from_node
			  and to_node = :old.to_node
		        order by assigned desc)
		     where rownum = 1);
    end if;

    -- update summary "transferred" when marked so the last time
    if :old.to_state < 3 and :new.to_state = 3 then
      update t_transfer_summary set completed = now
      where rowid = (select * from
		       (select rowid from t_transfer_summary
		        where guid = :old.guid
			  and from_node = :old.from_node
			  and to_node = :old.to_node
		        order by assigned desc)
		     where rownum = 1);
    end if;

    -- tick error count and time around error states
    if :old.to_state < 100 and :new.to_state >= 100 then
      update t_transfer_summary
      set errors = errors + 1, last_error_entry = now
      where rowid = (select * from
		       (select rowid from t_transfer_summary
		        where guid = :old.guid
			  and from_node = :old.from_node
			  and to_node = :old.to_node
		        order by assigned desc)
		     where rownum = 1);
    elsif :old.to_state >= 100 and :new.to_state < 100 then
      update t_transfer_summary
      set inerror = inerror + (now - last_error_entry), last_error_entry = null
      where rowid = (select * from
		       (select rowid from t_transfer_summary
		        where guid = :old.guid
			  and from_node = :old.from_node
			  and to_node = :old.to_node
		        order by assigned desc)
		     where rownum = 1);
    end if;

    -- we've collected all the info required for posterity, nuke
    -- t_transfer_state row for completed transfers
    if :new.to_state = 3 then
      delete from t_transfer_state where rowid = :new.rowid;
    end if;
  end;
/

show errors
