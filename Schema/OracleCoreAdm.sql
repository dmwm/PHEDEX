----------------------------------------------------------------------
-- Create tables

create sequence seq_adm_identity;
create sequence seq_adm_identity_attr;
create sequence seq_adm_client;
create sequence seq_adm_contact;
create sequence seq_adm_contact_attr;
create sequence seq_adm_site;

create table t_adm_identity
  (id			integer		not null);
   -- email_contact, distinguished_name

create table t_adm_identity_attr
  (id			integer		not null,
   identity		integer		not null,
   name			varchar (1000)	not null,
   value		varchar (4000));

create table t_adm_contact
  (id			integer		not null);
  -- remote_host -- user_agent -- referrer -- virtual_host
  -- server_host -- server_software -- request_method

create table t_adm_contact_attr
  (id			integer		not null,
   contact		integer		not null,
   name			varchar (1000)	not null,
   value		varchar (4000));

create table t_adm_client
  (id			integer		not null,
   identity		integer		not null,
   contact		integer		not null);

create table t_adm_site
  (id			integer		not null,
   name			varchar (1000)	not null);

create table t_adm_site_node
  (site			integer		not null,
   node			integer		not null);

create table t_adm_site_admin
  (site			integer		not null,
   identity		integer		not null);

create table t_adm_global_admin
  (identity		integer		not null);


----------------------------------------------------------------------
-- Add constraints

alter table t_adm_identity
  add constraint pk_adm_identity
  primary key (id);


alter table t_adm_identity_attr
  add constraint pk_adm_identity_attr
  primary key (id);

alter table t_adm_identity_attr
  add constraint uq_adm_identity_attr_key
  unique (identity, name);


alter table t_adm_contact
  add constraint pk_adm_contact
  primary key (id);

alter table t_adm_contact_attr
  add constraint uq_adm_contact_attr_key
  unique (contact, name);


alter table t_adm_client
  add constraint pk_adm_client
  primary key (id);

alter table t_adm_client
  add constraint uq_adm_client_key
  unique (identity, contact);

alter table t_adm_client
  add constraint fk_adm_client_identity
  foreign key (identity) references t_adm_identity (id);

alter table t_adm_client
  add constraint fk_adm_client_contact
  foreign key (contact) references t_adm_contact (id);


alter table t_adm_site
  add constraint pk_adm_site
  primary key (id);

alter table t_adm_site
  add constraint uq_adm_site_name
  unique (name);


alter table t_adm_site_node
  add constraint pk_adm_site_node
  primary key (site, node);

alter table t_adm_site_node
  add constraint fk_adm_site_node_site
  foreign key (site) references t_adm_site (id);

alter table t_adm_site_node
  add constraint fk_adm_site_node_node
  foreign key (node) references t_node (id);


alter table t_adm_site_admin
  add constraint pk_adm_site_admin
  primary key (site, identity);

alter table t_adm_site_admin
  add constraint fk_adm_site_admin_site
  foreign key (site) references t_adm_site (id);

alter table t_adm_site_admin
  add constraint fk_adm_site_admin_identity
  foreign key (identity) references t_adm_identity (id);


alter table t_adm_global_admin
  add constraint pk_adm_global_admin
  primary key (identity);

alter table t_adm_global_admin
  add constraint fk_adm_global_admin_identity
  foreign key (identity) references t_adm_identity (id);
