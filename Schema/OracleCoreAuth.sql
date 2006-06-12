----------------------------------------------------------------------
-- Create tables

create table t_authorisation
  (timestamp		float		not null,
   role_name		varchar (40)	not null,
   email_contact	varchar (100)	not null,
   distinguished_name	varchar (200)	not null);

----------------------------------------------------------------------
-- Add constraints

alter table t_authorisation
  add constraint pk_authorisation
  primary key (role_name);
