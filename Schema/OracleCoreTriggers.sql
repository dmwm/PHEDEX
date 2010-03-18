set scan off;

/* Keep block file and byte totals current in the block record when
   changing the files.  Supports the following:
     - file added or removed bytes
     - file inserted or deleted
     - file moved from one block to another
 */
create or replace trigger tr_dps_file_block
  after insert or update or delete on t_dps_file for each row declare
    unixtime integer := now();
  begin
    if (updating and :old.inblock = :new.inblock) then
        update t_dps_block
           set bytes = bytes - :old.filesize + :new.filesize,
               time_update = unixtime
         where id = :new.inblock;
	return;
    end if;

    if (inserting or updating) then
      update t_dps_block
      set files = files + 1,
          bytes = bytes + :new.filesize,
	  time_update = unixtime
      where id = :new.inblock;
    end if;

    if (updating or deleting) then
      update t_dps_block
      set files = files - 1,
          bytes = bytes - :old.filesize,
	  time_update = unixtime
      where id = :old.inblock;
    end if;
  end;
/
show errors;

/* Keep dataset block, file and byte totals current in the block
   record when changing the blocks.  Supports the following:
     - block added or removed files/bytes
     - block inserted or deleted
     - block moved from one dataset to another
 */
create or replace trigger tr_dps_block_dataset
  after insert or update or delete on t_dps_block for each row declare
    unixtime integer := now();
  begin
    if (updating and :old.dataset = :new.dataset) then
        update t_dps_dataset
           set files = files - :old.files + :new.files,
               bytes = bytes - :old.bytes + :new.bytes,
               time_update = unixtime
         where id = :new.dataset;
	return;
    end if;

    if (inserting or updating) then
      update t_dps_dataset
      set blocks = blocks + 1,
          files = files + :new.files,
          bytes = bytes + :new.bytes,
	  time_update = unixtime
      where id = :new.dataset;
    end if;

    if (updating or deleting) then
      update t_dps_dataset
      set blocks = blocks - 1,
          files = files - :old.files,
          bytes = bytes - :old.bytes,
	  time_update = unixtime
      where id = :old.dataset;
    end if;
  end;
/
show errors;

/* Insert new requests for new files in an already-active block
   destination.
   These requests start in state -1 and will be allocated when 
   there is space available in the queue.  */
create or replace trigger tr_xfer_file_insert
  after insert on t_xfer_file for each row declare
    unixtime integer := now();
  begin
    insert into t_xfer_request
      (fileid, inblock, destination, priority, is_custodial,
       state, attempt, time_create, time_expire)
      select :new.id, :new.inblock, bd.destination, bd.priority,
             bd.is_custodial, -1 state, 0 attempt, unixtime, unixtime
      from t_dps_block_dest bd where bd.block = :new.inblock and bd.state = 1;
  end;
/
show errors;

/* Insert new requests for replicas deleted from an already-active
   block destination.  (to trigger a retransfer)
   These requests start in state -1 and will be allocated when 
   there is space available in the queue.  */
create or replace trigger tr_xfer_replica_delete
  after delete on t_xfer_replica for each row declare
    unixtime integer := now();
  begin
    insert into t_xfer_request
      (fileid, inblock, destination, priority, is_custodial,
       state, attempt, time_create, time_expire)
      select f.id, f.inblock, bd.destination, bd.priority, bd.is_custodial,
             -1 state, 0 attempt, unixtime, unixtime
      from t_xfer_file f join t_dps_block_dest bd on bd.block = f.inblock
      where f.id = :old.fileid
        and bd.state = 1
	and bd.destination = :old.node
	and not exists
	  (select 1 from t_xfer_request xq
	   where xq.fileid = f.id and xq.destination = bd.destination);
  end;
/
show errors;
