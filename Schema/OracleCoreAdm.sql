----------------------------------------------------------------------
-- Create tables

create sequence seq_adm_identity;
create sequence seq_adm_identity_attr;
create sequence seq_adm_client;
create sequence seq_adm_contact;
create sequence seq_adm_contact_attr;
create sequence seq_adm_site;

create table t_adm_identity
  (id			integer		not null,
   --
   constraint pk_adm_identity
     primary key (id));

create table t_adm_identity_attr
  (id			integer		not null,
   identity		integer		not null,
   name			varchar (1000)	not null,
   value		varchar (4000),
   --
   constraint pk_adm_identity_attr
     primary key (id),
   --
   constraint uq_adm_identity_attr_key
     unique (identity, name),
   --
   constraint uq_adm_identity_attr_value
     unique (name, value));


create table t_adm_contact
  (id			integer		not null,
   --
   constraint pk_adm_contact
     primary key (id));


create table t_adm_contact_attr
  (id			integer		not null,
   contact		integer		not null,
   name			varchar (1000)	not null,
   value		varchar (4000),
   --
   constraint pk_adm_contact_attr
     primary key (id),
   --
   constraint uq_adm_contact_attr_key
     unique (contact, name));


create table t_adm_client
  (id			integer		not null,
   identity		integer		not null,
   contact		integer		not null,
   --
   constraint pk_adm_client
     primary key (id),
   --
   constraint uq_adm_client_key
     unique (identity, contact),
   --
   constraint fk_adm_client_identity
     foreign key (identity) references t_adm_identity (id),
   --
   constraint fk_adm_client_contact
     foreign key (contact) references t_adm_contact (id));


create table t_adm_site
  (id			integer		not null,
   name			varchar (1000)	not null,
   role_name		varchar (40)	not null,
   --
   constraint pk_adm_site
     primary key (id),
   --
   constraint uq_adm_site_name
     unique (name),
   --
   constraint uq_adm_site_role
     unique (role_name));


create table t_adm_site_node
  (site			integer		not null,
   node			integer		not null,
   --
   constraint pk_adm_site_node
     primary key (site, node),
   --
   constraint fk_adm_site_node_site
     foreign key (site) references t_adm_site (id)
     on delete cascade,
   --
   constraint fk_adm_site_node_node
     foreign key (node) references t_adm_node (id)
     on delete cascade);


create table t_adm_site_admin
  (site			integer		not null,
   identity		integer		not null,
   --
   constraint pk_adm_site_admin
     primary key (site, identity),
   --
   constraint fk_adm_site_admin_site
     foreign key (site) references t_adm_site (id)
     on delete cascade,
   --
   constraint fk_adm_site_admin_identity
     foreign key (identity) references t_adm_identity (id)
     on delete cascade);


create table t_adm_global_admin
  (identity		integer		not null,
   --
   constraint pk_adm_global_admin
     primary key (identity),
   --
   constraint fk_adm_global_admin_id
     foreign key (identity) references t_adm_identity (id)
     on delete cascade);

----------------------------------------------------------------------
-- Create indices

create index ix_adm_client_contact
  on t_adm_client (contact);

create index ix_adm_site_admin_identity
  on t_adm_site_admin (identity);

create index ix_adm_site_node_node
  on t_adm_site_node (node);
