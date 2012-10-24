----------------------------------------------------------------------
-- Create tables

/* Definition of Roles and Domains for the persons authorised to act on requests 
 */

create sequence seq_adm2_role;

create table t_adm2_role
  (id			integer		not null, -- ID for PhEDEx use
   role			varchar (200)	not null, -- Role name like in SiteDB
   domain		varchar (200)   not null, -- To distinguish between
                                                  -- sites, groups, etc
   --
   constraint uk_adm2_role_id_role_domain
     unique (role, domain),
   --
   constraint pk_adm2_role_id
     primary key (id)
);

/* Some static roles */
insert into t_adm2_role (id, role, domain)
  values (seq_adm2_role.nextval, 'Data Manager', 'site');
insert into t_adm2_role (id, role, domain)
  values (seq_adm2_role.nextval, 'Data Manager', 'group');
insert into t_adm2_role (id, role, domain)
  values (seq_adm2_role.nextval, 'Site Admin', 'site');
insert into t_adm2_role (id, role, domain)
  values (seq_adm2_role.nextval, 'Group Manager', 'group');
insert into t_adm2_role (id, role, domain)
  values (seq_adm2_role.nextval, 'Admin', 'phedex');
insert into t_adm2_role (id, role, domain)
  values (seq_adm2_role.nextval, 'Operator', 'phedex/prod');
insert into t_adm2_role (id, role, domain)
  values (seq_adm2_role.nextval, 'Unprivileged User', 'any');
insert into t_adm2_role (id, role, domain)
  values (seq_adm2_role.nextval, 'Agent', 'phedex');
 
----------------------------------------------------------------------
