-- Typical PhEDEx accounts, run this in "sqlplus /nolog":
connect sys as sysdba

create user "CMS_TRANSFERMGMT"
  profile "DEFAULT"
  identified by "smallAND_round"
  default tablespace "PHEDEX"
  temporary tablespace "TEMP"
  account unlock;
create user "CMS_TRANSFERMGMT_WRITER"
  profile "DEFAULT"
  identified by "threeBagsFULL"
  default tablespace "PHEDEX"
  temporary tablespace "TEMP"
  account unlock;
create user "CMS_TRANSFERMGMT_READER"
  profile "DEFAULT"
  identified by "slightlyJaundiced"
  default tablespace "PHEDEX"
  temporary tablespace "TEMP"
  account unlock;

grant "CONNECT"				to "CMS_TRANSFERMGMT";
grant "CONNECT"				to "CMS_TRANSFERMGMT_WRITER";
grant "CONNECT"				to "CMS_TRANSFERMGMT_READER";
grant "RESOURCE"			to "CMS_TRANSFERMGMT";
grant "RESOURCE"			to "CMS_TRANSFERMGMT_WRITER";
grant unlimited tablespace		to "CMS_TRANSFERMGMT";
grant unlimited tablespace		to "CMS_TRANSFERMGMT_WRITER";

alter user "CMS_TRANSFERMGMT"		default role all;
alter user "CMS_TRANSFERMGMT_WRITER"	default role all;
alter user "CMS_TRANSFERMGMT_READER"	default role all;
