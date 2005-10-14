-- PhEDEx ORACLE schema for authorisations.
-- REQUIRES: None.

----------------------------------------------------------------------
-- Create new tables

create table t_authorisation
  (timestamp		float		not null,
   role_name		varchar (20)	not null,
   email_contact	varchar (100)	not null,
   distinguished_name	varchar (200)	not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_authorisation
  add constraint pk_authorisation
  primary key (role_name)
  using index tablespace CMS_TRANSFERMGMT_INDX01;

----------------------------------------------------------------------
-- Add indices
