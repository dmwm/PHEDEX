-- A few time functions to make the operators life a little easier

-- returns a human-readable date if given a unix timestamp
create or replace function gmtime(unixtimestamp in integer) return varchar is
 result varchar(19);
begin
 result := TO_CHAR(TO_DATE('1970-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS') + numtodsinterval(unixtimestamp, 'SECOND'), 'YYYY-MM-DD HH24:MI:SS');
 return(result);
end gmtime;
/

-- returns the current time as a unix timestamp
create or replace function now return number is
  result number;
begin
  result := (sysdate - TO_DATE('1970-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS')) * 24*60*60;
return(result);
end now;
/

