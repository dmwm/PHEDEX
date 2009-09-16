set scan off;

create or replace trigger tr_dps_file_block
  after insert or update or delete on t_dps_file for each row declare
    unixtime integer
      := 86400 * (sysdate - to_date('01/01/1970 00:00:00', 'DD/MM/YYYY HH24:MI:SS'));
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

create or replace trigger tr_xfer_file_insert
  after insert on t_xfer_file for each row declare
    unixtime integer
      := 86400 * (sysdate - to_date('01/01/1970 00:00:00', 'DD/MM/YYYY HH24:MI:SS'));
  begin
    insert into t_xfer_request
      (fileid, inblock, destination, priority, is_custodial,
       state, attempt, time_create, time_expire)
      select :new.id, :new.inblock, bd.destination, bd.priority,
             bd.is_custodial, 0 state, 1 attempt, unixtime, unixtime + 8*3600
      from t_dps_block_dest bd where bd.block = :new.inblock and bd.state = 1;
  end;
/

/* FIXME: Analyse if this trigger is really needed.  At present
   FileRouter in any cases removes requests for which replica
   exists because it may create requests for files a node is
   a source for and therefore this trigger would not delete.
create or replace trigger tr_xfer_replica_insert
  after insert on t_xfer_replica for each row begin
    delete from t_xfer_request
    where fileid = :new.fileid and destination = :new.node;
  end;
/
*/

create or replace trigger tr_xfer_replica_delete
  after delete on t_xfer_replica for each row declare
    unixtime integer
      := 86400 * (sysdate - to_date('01/01/1970 00:00:00', 'DD/MM/YYYY HH24:MI:SS'));
  begin
    insert into t_xfer_request
      (fileid, inblock, destination, priority, is_custodial,
       state, attempt, time_create, time_expire)
      select f.id, f.inblock, bd.destination, bd.priority, bd.is_custodial,
             0 state, 1 attempt, unixtime, unixtime + 8*3600
      from t_xfer_file f join t_dps_block_dest bd on bd.block = f.inblock
      where f.id = :old.fileid
        and bd.state = 1
	and bd.destination = :old.node
	and not exists
	  (select 1 from t_xfer_request xq
	   where xq.fileid = f.id and xq.destination = bd.destination);
  end;
/

show errors
