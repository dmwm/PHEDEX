-- PhEDEx ORACLE schema for agent operations.
-- NB: s/CMS_TRANSFERMGMT_INDX01/INDX01/g for devdb9
-- REQUIRES: OracleCoreTopo.sql

----------------------------------------------------------------------
-- Drop old tables

drop table t_subscriptions;

----------------------------------------------------------------------
-- Create new tables

create table t_subscriptions
	(destination		varchar (20),
	 dataset		varchar (1000)	not null,
	 owner			varchar (1000)	not null);

----------------------------------------------------------------------
-- Add constraints

----------------------------------------------------------------------
-- Add indices

