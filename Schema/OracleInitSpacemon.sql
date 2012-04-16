-- Load new tables
-- set def OFF then to '&' to avoid misleading SP2-0317 error.
set def OFF
set echo off feedback off sqlprompt '' def &
prompt
prompt Loading PhEDEx schema to &_user@&_connect_identifier

prompt
prompt Loading files
@@OracleSpacemon.sql

prompt
prompt PhEDEx schema loaded
prompt
