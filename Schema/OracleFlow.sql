-- PhEDEx ORACLE schema for agent operations.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: None.

----------------------------------------------------------------------
-- Drop old tables

drop table t_subscriptions;

----------------------------------------------------------------------
-- Create new tables

create table t_subscriptions
  (dataset		varchar (1000)	not null,
   owner		varchar (1000)	not null,
   destination		varchar (20));

----------------------------------------------------------------------
-- Add constraints

----------------------------------------------------------------------
-- Add indices

create index ix_subscriptions_dso
  on t_subscriptions (dataset, owner)
  tablespace CMS_TRANSFERMGMT_INDX01;

create index ix_subscriptions_dest
  on t_subscriptions (destination)
  tablespace CMS_TRANSFERMGMT_INDX01;
