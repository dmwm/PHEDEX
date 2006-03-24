----------------------------------------------------------------------
-- Log into t_xfer_tracking changes to t_xfer_state.

create or replace trigger tr_xfer_state_available
  after update of time_available on t_xfer_state for each row begin
    insert into t_xfer_tracking (timestamp, from_node, to_node,
				 priority, fileid, reason)
    values (:new.time_available, :new.from_node, :new.to_node,
	     :new.priority, :new.fileid, 'avail');
  end;
/

create or replace trigger tr_xfer_state_start
  after update of time_xfer_start on t_xfer_state for each row begin
    insert into t_xfer_tracking (timestamp, from_node, to_node,
				 priority, fileid, reason)
    values (:new.time_xfer_start, :new.from_node, :new.to_node,
	     :new.priority, :new.fileid, 'try');
  end;
/

create or replace trigger tr_xfer_state_end
  after update of time_xfer_end on t_xfer_state for each row begin
    insert into t_xfer_tracking (timestamp, from_node, to_node,
			         priority, fileid, reason)
    values (:new.time_xfer_end, :new.from_node, :new.to_node,
	    :new.priority, :new.fileid, 'done');
  end;
/

create or replace trigger tr_xfer_state_error
  after update of time_error_start on t_xfer_state for each row begin
    insert into t_xfer_tracking (timestamp, from_node, to_node,
				 priority, fileid, reason)
    values (:new.time_error_start, :new.from_node, :new.to_node,
	     :new.priority, :new.fileid, 'fail');
  end;
/

show errors
