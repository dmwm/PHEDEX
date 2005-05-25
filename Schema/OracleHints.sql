-- create indices for foreign keys, otherwise locks entire table on update
-- index/hash organised table (iot) for t_routing, t_replica_state?
-- www.cern.ch/it-db -> Oracle @ CERN -> Sessions -> pdb01/cms -> login
-- explain plan for ...
-- @?/rdbms/admin/utilxpls.sql
-- select plan_table_output from table(dbms_xplan.display('plan_table',null,'serial'))
-- desc dbms_stats (in oradoc)
-- analyze
-- set timing on
-- oradoc.cern.ch
-- sqlplus / l / 16 / del / &foo
-- create trigger for transfer history

/*
I have enabled the feature allowing you to manage access privileges to
your data with password-protected roles for 3 CMS Transfer Management
accounts on CMSSG. What you should do in order to implement your data
access policy is the following:
- as CMS_TRANSFERMGMT user create appropriate roles with command:
    CREATE ROLE role_name IDENTIFIED BY some_password;
- Grant all desired object privileges to those roles:
    GRANT privilege_name ON object_name TO role_name;
- Grant roles to CMS_TRANSFERMGMT_READER and/or CMS_TRANSFERMGMT_WRITER
  accounts:
    GRANT role_name to CMS_TRANSFERMGMT_READER | CMS_TRANSFERMGMT_WRITER
- Change your application in a way that after connection to
  CMS_TRANSFERMGMT_READER or CMS_TRANSFERMGMT_WRITER account it enables
  one of the created roles (I guess that it doesn't matter too much that
  it is not possible to use bind variables in this case as long as the
  query below is not executed too often):
    SET ROLE role_name IDENTIFIED BY some_password, DESIGNER;

Role DESIGNER is a role that all your account have by default so probably
it is reasonable to keep this role active.  */
