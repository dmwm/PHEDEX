----------------------------------------------------------------------
-- Create tables

/* Definition of Roles and Domains for the persons authorised to act on requests 
 */

create sequence seq_adm2_role;
create sequence seq_adm2_domain;

create table t_adm2_role
  (id			integer		not null, -- ID for PhEDEx use
   name			varchar (200)	not null, -- Role name like in SiteDB
   --
   constraint uk_adm2_role_id_name
     unique (id, name),
   --
   constraint pk_adm2_role_id
     primary key (id)
);

create table t_adm2_domain
  (id			integer		not null, -- ID for PhEDEx use
   name			varchar (200)	not null, -- Domain name to distinguish between sites, groups, etc
   --
   constraint uk_adm2_domain_id_name
     unique (id, name),
   --
   constraint pk_adm2_domain_id
     primary key (id)
);

/* Some static roles */
insert into t_adm2_role (id, name)
  values (seq_adm2_role.nextval, 'Data Manager');
insert into t_adm2_role (id, name)
  values (seq_adm2_role.nextval, 'Site Admin');
insert into t_adm2_role (id, name)
  values (seq_adm2_role.nextval, 'Group Manager');
insert into t_adm2_role (id, name)
  values (seq_adm2_role.nextval, 'Admin');
insert into t_adm2_role (id, name)
  values (seq_adm2_role.nextval, 'Operator');
insert into t_adm2_role (id, name)
  values (seq_adm2_role.nextval, 'Unprivileged User');
insert into t_adm2_role (id, name)
  values (seq_adm2_role.nextval, 'Agent');

/* Domains */
insert into t_adm2_domain (id, name)
  values (seq_adm2_domain.nextval, 'site');
insert into t_adm2_domain (id, name)
  values (seq_adm2_domain.nextval, 'group');
insert into t_adm2_domain (id, name)
  values (seq_adm2_domain.nextval, 'phedex');
insert into t_adm2_domain (id, name)
  values (seq_adm2_domain.nextval, 'phedex/prod');

----------------------------------------------------------------------
-- Create indices

create index ix_adm2_roles_name
  on t_adm2_role (name);

create index ix_adm2_domain_name
  on t_adm2_domain (name);
