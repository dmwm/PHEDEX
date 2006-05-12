----------------------------------------------------------------------
-- Log into t_xfer_tracking changes to t_xfer_state.

create or replace trigger tr_xfer_file_insert
  after insert on t_xfer_file for each row declare
    unixtime integer
      := 24*60*60 + (sysdate - to_date('01/01/1970 00:00:00', 'DD/MM/YYYY HH24:MI:SS'));
  begin
    insert into t_xfer_request
      (fileid, inblock, destination, priority,
       state, attempt, time_create, time_expire)
      select :new.id, :new.inblock, bd.destination, bd.priority,
             0 state, 1 attempt, unixtime, unixtime + 8*3600
      from t_dps_block_dest bd where bd.block = :new.inblock and bd.state = 1;
  end;
/

create or replace trigger tr_xfer_state_available
  after update of time_available on t_xfer_state for each row begin
    if :new.time_available is not null then
      insert into t_xfer_tracking
        (timestamp, from_node, to_node, priority, fileid,
        is_avail, is_try, is_done, is_fail, is_expire)
      values
        (:new.time_available, :new.from_node, :new.to_node, :new.priority,
         :new.fileid, 1, 0, 0, 0, 0);
    end if;
  end;
/

create or replace trigger tr_xfer_state_start
  after update of time_xfer_start on t_xfer_state for each row begin
    if :new.time_xfer_start is not null then
      insert into t_xfer_tracking
        (timestamp, from_node, to_node, priority, fileid,
         is_avail, is_try, is_done, is_fail, is_expire)
      values
        (:new.time_xfer_start, :new.from_node, :new.to_node, :new.priority,
         :new.fileid, 0, 1, 0, 0, 0);
    end if;
  end;
/

create or replace trigger tr_xfer_state_end
  after update of time_xfer_end on t_xfer_state for each row begin
    if :new.time_xfer_end is not null then
      insert into t_xfer_tracking
        (timestamp, from_node, to_node, priority, fileid,
         is_avail, is_try, is_done, is_fail, is_expire)
      values
        (:new.time_xfer_end, :new.from_node, :new.to_node, :new.priority,
         :new.fileid, 0, 0, 1, 0, 0);
    end if;
  end;
/

create or replace trigger tr_xfer_state_error
  after update of time_error_start on t_xfer_state for each row begin
    if :new.time_error_start is not null then
      insert into t_xfer_tracking
        (timestamp, from_node, to_node, priority, fileid,
         is_avail, is_try, is_done, is_fail, is_expire)
      values
        (:new.time_error_start, :new.from_node, :new.to_node, :new.priority,
         :new.fileid, 0, 0, 0, 1, 0);
    end if;
  end;
/

show errors
