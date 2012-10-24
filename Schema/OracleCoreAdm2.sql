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
   constraint pk_adm2_role_id
     primary key (id),
   --	
   constraint uk_adm2_role_id_role_domain
     unique (role, domain)
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

/*
Definition of abilites granted to groups of roles for request approval.
Any person with any such role can partially approve the request; the request
is fully approved when all required abilities have approved it.
 */

create sequence seq_adm2_ability;

create table t_adm2_ability
  (id			integer		not null, -- ID for PhEDEx use
   name			varchar (200)	not null, -- ability name
   --
   constraint pk_adm2_ability
     primary key (id),
   --
   constraint uk_adm2_ability_name
     unique (name)
);

/* Some static abilities */
insert into t_adm2_ability (id, name)
  values (seq_adm2_ability.nextval, 'subscribe');
insert into t_adm2_ability (id, name)
  values (seq_adm2_ability.nextval, 'delete_noncustodial');
insert into t_adm2_ability (id, name)
  values (seq_adm2_ability.nextval, 'delete_custodial');
insert into t_adm2_ability (id, name)
  values (seq_adm2_ability.nextval, 'invalidate');

----------------------------------------------------------------------

/*
Map of abilities to roles
 */

create sequence seq_adm2_ability_map;

create table t_adm2_ability_map
  (id			integer		not null, -- ID for PhEDEx use
   ability		integer		not null,
   role			integer		not null,
   --
   constraint pk_adm2_ability_map
     primary key (id),
   --
   constraint uk_adm2_ability_map_role
     unique (ability, role)
);

/* Some static ability mappings */
insert into t_adm2_ability_map (id, ability, role)
  select seq_adm2_ability_map.nextval, ab.id, rl.id
	from t_adm2_ability ab, t_adm2_role rl
	where ab.name='subscribe' and rl.role='Data Manager'
		and rl.domain like '%';

