----------------------------------------------------------------------
-- Prototype of new request schema for Oct2011 CodeFest

create sequence seq_req2_type;

/* Type of request */
create table t_req2_type
  (id			integer		not null,
   name			varchar(100)	not null,
   --
   constraint pk_req2_type
     primary key (id),
   --
   constraint uk_req2_type_name
     unique (name)
);
/* Fixed data for types */
insert into t_req2_type (id, name)
  values (seq_req2_type.nextval, 'xfer');
insert into t_req2_type (id, name)
   values (seq_req2_type.nextval, 'delete');
insert into t_req2_type (id, name)
   values (seq_req2_type.nextval, 'invalidation');
insert into t_req2_type (id, name)
   values (seq_req2_type.nextval, 'consistency');


-- 
/* Table t_req2_state of states in the request state machine */

create sequence seq_req2_state;

create table t_req2_state
  (id			integer		not null,
   name			varchar(100)	not null,
   --
   constraint pk_req2_state
     primary key (id),
   --
   constraint uk_req2_state_name
     unique (name)
);

/* Fixed data for states */
insert into t_req2_state (id, name)
  values (seq_req2_state.nextval, 'created');
insert into t_req2_state (id, name)
   values (seq_req2_state.nextval, 'suspended');
insert into t_req2_state (id, name)
   values (seq_req2_state.nextval, 'partiallyapproved');
insert into t_req2_state (id, name)
   values (seq_req2_state.nextval, 'approved');
insert into t_req2_state (id, name)
   values (seq_req2_state.nextval, 'denied');
insert into t_req2_state (id, name)
   values (seq_req2_state.nextval, 'cancelled');
insert into t_req2_state (id, name)
   values (seq_req2_state.nextval, 'done');

/* Main request table */

create sequence seq_req2_request;

create table t_req2_request
  (id			integer		not null,
   type			integer		not null,
   state		integer		not null,
   created_by		integer		not null,  -- who created the request
   time_create		float		not null,
   time_end		float			,  -- time when the request reached a terminal state, after which the request can be cleaned up
   --
   constraint pk_req2_request
     primary key (id),
   --
   constraint fk_req2_request_type
     foreign key (type) references t_req2_type (id),
   --
   constraint fk_req2_request_state
     foreign key (state) references t_req2_state (id),
   --
   constraint fk_req2_request_created_by
     foreign key (created_by) references t_adm_client (id)
);

create index ix_req2_request_by
  on t_req2_request (created_by);

create index ix_req2_request_type
  on t_req2_request (type);

create index ix_req2_request_state
  on t_req2_request (state);

--

/* t_req2_transition table of allowed state changes in the
   request finite state machine */

create sequence seq_req2_transition;

create table t_req2_transition
  (id			integer		not null,
   from_state		integer		not null,
   to_state		integer		not null,
   --
   constraint pk_req2_transition
     primary key (id),
   --
   constraint uk_req2_transition_from_to
     unique (from_state, to_state),
   --
   constraint fk_req2_transition_from
     foreign key (from_state) references t_req2_state (id),
   --
   constraint fk_req2_transition_to
     foreign key (to_state) references t_req2_state (id)
);   

create index ix_req2_transition_from
  on t_req2_transition (from_state);

create index ix_req2_transition_to
  on t_req2_transition (to_state);

/* Add some state transitions */

insert into t_req2_transition (id, from_state, to_state)
  select seq_req2_transition.nextval, rf.id, rt.id
	from t_req2_state rf, t_req2_state rt
	where rf.name='created' and rt.name='approved';
insert into t_req2_transition (id, from_state, to_state)
  select seq_req2_transition.nextval, rf.id, rt.id
	from t_req2_state rf, t_req2_state rt
	where rf.name='created' and rt.name='denied';
insert into t_req2_transition (id, from_state, to_state)
  select seq_req2_transition.nextval, rf.id, rt.id
	from t_req2_state rf, t_req2_state rt
	where rf.name='created' and rt.name='suspended';
insert into t_req2_transition (id, from_state, to_state)
  select seq_req2_transition.nextval, rf.id, rt.id
	from t_req2_state rf, t_req2_state rt
	where rf.name='approved' and rt.name='cancelled';
insert into t_req2_transition (id, from_state, to_state)
  select seq_req2_transition.nextval, rf.id, rt.id
	from t_req2_state rf, t_req2_state rt
	where rf.name='approved' and rt.name='done';

/* t_req2_rule table of allowed state changes for each request type in the
   request finite state machine */

create sequence seq_req2_rule;

create table t_req2_rule
  (id			integer		not null,
   type			integer		not null,
   transition		integer		not null,
   --
   constraint pk_req2_rule
     primary key (id),
   --
   constraint uk_req2_rule
     unique (type, transition),
   --
   constraint fk_req2_rule_type
     foreign key (type) references t_req2_type (id),
   --
   constraint fk_req2_transition
     foreign key (transition) references t_req2_transition (id)
);   

create index ix_req2_rule_type
  on t_req2_rule (type);

create index ix_req2_rule_transition
  on t_req2_rule (transition);

/* Add some transition rules */

insert into t_req2_rule (id, type, transition)
  select seq_req2_rule.nextval, rtp.id, rt.id
	from t_req2_type rtp, t_req2_transition rt
	join t_req2_state rtf on rt.from_state=rtf.id
	join t_req2_state rtt on rt.to_state=rtt.id
	where rtp.name='xfer' and
	rtf.name='created' and rtt.name='approved';
insert into t_req2_rule (id, type, transition)
  select seq_req2_rule.nextval, rtp.id, rt.id
	from t_req2_type rtp, t_req2_transition rt
	join t_req2_state rtf on rt.from_state=rtf.id
	join t_req2_state rtt on rt.to_state=rtt.id
	where rtp.name='delete' and
	rtf.name='created' and rtt.name='denied';
insert into t_req2_rule (id, type, transition)
  select seq_req2_rule.nextval, rtp.id, rt.id
	from t_req2_type rtp, t_req2_transition rt
	join t_req2_state rtf on rt.from_state=rtf.id
	join t_req2_state rtt on rt.to_state=rtt.id
	where rtp.name='invalidation' and
	rtf.name='approved' and rtt.name='cancelled';

/* t_req2_permission table of allowed state changes per role and domain */

create sequence seq_req2_permission;

create table t_req2_permission
  (id			integer		not null,
   rule			integer		not null,
   role			integer		not null,
   domain		integer		not null,
   --
   constraint pk_req2_permission
     primary key (id),
   --
   constraint uk_req2_permission
     unique (rule, role, domain),
   --
   constraint fk_req2_permission_rule
     foreign key (rule) references t_req2_rule (id),
   --
   constraint fk_req2_permission_role
     foreign key (role) references t_adm2_role (id),
   --
   constraint fk_req2_permission_domain
     foreign key (domain) references t_adm2_domain (id)
);   

create index ix_req2_permission_rule
  on t_req2_permission (rule);

create index ix_req2_permission_role
  on t_req2_permission (role);

create index ix_req2_permission_domain
  on t_req2_permission (domain);

/* Add some transition rules */

insert into t_req2_permission (id, rule, role, domain)
  select seq_req2_permission.nextval, rr.id, ar.id, ad.id
	from t_req2_rule rr, t_adm2_role ar, t_adm2_domain ad
	join t_req2_transition rt on rt.id=rr.transition
	join t_req2_type rtp on rtp.id=rr.type
	join t_req2_state rtf on rt.from_state=rtf.id
	join t_req2_state rtt on rt.to_state=rtt.id
	where rtp.name='xfer' and
	rtf.name='created' and rtt.name='approved'
	and ar.name='Data Manager' and ad.name='phedex';
