----------------------------------------------------------------------
-- Create sequences

create sequence seq_adm_node;
create sequence seq_adm_link;

----------------------------------------------------------------------
-- Create tables

create table t_adm_node
  (id			integer		not null,
   name			varchar (20)	not null,
   kind			varchar (20)	not null,
   technology		varchar (20)	not null,
   se_name		varchar (80),
   capacity		integer,
   bandwidth_cap	integer,
   --
   constraint pk_adm_node
     primary key (id),
   --
   constraint uq_adm_node_name
     unique (name),
   --
   constraint ck_adm_node_kind
     check (kind in ('Buffer', 'MSS', 'Disk')),
   --
   constraint ck_adm_node_technology
     check (technology in ('dCache', 'Castor', 'DPM', 'Disk', 'Other')));


create table t_adm_link
  (id			integer		not null,
   from_node		integer		not null,
   to_node		integer		not null,
   distance		integer		not null,
   is_local		char (1)	not null,
   is_active		char (1)	not null,
   is_preferred		char (1)	not null,
   bandwidth_cap	integer,
   --
   constraint pk_adm_link
     primary key (id),
   --
   constraint uq_adm_link_key
     unique (from_node, to_node),
   --
   constraint fk_adm_link_from
     foreign key (from_node) references t_adm_node (id),
   --
   constraint fk_adm_link_to
     foreign key (to_node) references t_adm_node (id),
   --
   constraint ck_adm_link_local
     check (is_local in ('y', 'n')),
   --
   constraint ck_adm_link_active
     check (is_active in ('y', 'n')),
   --
   constraint ck_adm_link_preferred
     check (is_preferred in ('y', 'n')));


create table t_adm_share
  (node			integer		not null,
   priority		integer		not null,
   fair_share		integer		not null,
   --
   constraint pk_adm_share
     primary key (node, priority),
   --
   constraint fk_adm_share_node
     foreign key (node) references t_adm_node (id));


create table t_adm_link_param
  (link			integer		not null,
   time_update		float		not null,
   time_span		integer,
   pend_bytes		float,
   done_bytes		float,
   try_bytes		float,
   xfer_rate		float,
   xfer_latency		float,
   --
   constraint pk_adm_link_param
     primary key (link),
   --
   constraint fk_adm_link_param_link
     foreign key (link) references t_adm_link (id))
 --
 organization index;
