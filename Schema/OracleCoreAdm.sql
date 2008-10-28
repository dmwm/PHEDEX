----------------------------------------------------------------------
-- Create tables

create sequence seq_adm_identity;
create sequence seq_adm_client;
create sequence seq_adm_contact;
create sequence seq_adm_contact_attr;

/* Information gathered from Site DB via Security Module.
 * This information is for historical reference only, not an
 * up-to-date list of users.  For that, site DB is used. As this is
 * historical information, entries here should not be deleted.
 */
create table t_adm_identity
  (id			integer		not null, -- ID for PhEDEx use
   secmod_id		integer			, -- SecurityModule ID number
   name			varchar (4000)		, -- SecurityModule name (forename + surname)
   email		varchar (4000)		, -- SecurityModule email
   dn			varchar (4000)		, -- SecurityModule Distinguished name
   certificate		varchar (4000)		, -- SecurityModule certificate
   username		varchar (4000)		, -- SecurityModule username (hypernews)
   time_update		integer			, -- Time last updated
   --
   constraint pk_adm_identity
     primary key (id)
);

/* A logged access from the web page */
create table t_adm_contact
  (id			integer		not null,
   --
   constraint pk_adm_contact
     primary key (id));

/* contact name/value attributes */
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
     unique (contact, name),
   --
   constraint fk_adm_contact_attr_contact
     foreign key (contact) references t_adm_contact (id)
     on delete cascade);

/* map of identity to contact */
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

/* Map of identity to node for web page user preferences */
create table t_adm_my_node
  (identity		integer		not null,
   node			integer		not null,
   --
   constraint pk_adm_my_node
     primary key (identity, node),
   --
   constraint fk_adm_my_node_identity
     foreign key (identity) references t_adm_identity (id)
     on delete cascade,
   constraint fk_adm_my_node_node
     foreign key (node) references t_adm_node (id)
     on delete cascade);

----------------------------------------------------------------------
-- Create indices

create index ix_adm_identity_secmod_id
  on t_adm_identity (secmod_id);

create index ix_adm_identity_dn
  on t_adm_identity (dn);

create index ix_adm_client_contact
  on t_adm_client (contact);
