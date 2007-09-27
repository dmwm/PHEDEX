create table t_dvs_status
 (id		integer not null,
  name		varchar2(30),
  description	varchar2(100),
  --
  constraint pk_dvs_status primary key(id),
  --
  constraint uq_dvs_status_name unique(name),
  constraint uq_dvs_status_description unique(description)
 );
insert into t_dvs_status (id,name,description) values
	 (0,'None','Request exists, but has never been looked at');
insert into t_dvs_status (id,name,description) values
	 (1,'OK','Success');
insert into t_dvs_status (id,name,description) values
	 (2,'Fail','Failure');
insert into t_dvs_status (id,name,description) values
	 (3,'Queued','Queued, waiting for a worker to run it');
insert into t_dvs_status (id,name,description) values
	 (4,'Active','Active, being run as we speak!');
insert into t_dvs_status (id,name,description) values
	 (5,'Timeout','Timed out waiting for the worker');
insert into t_dvs_status (id,name,description) values
	 (6,'Expired','Not enough results returned in time');
insert into t_dvs_status (id,name,description) values
	 (7,'Suspended','Waiting for operator intervention');
insert into t_dvs_status (id,name,description) values
	 (8,'Error','Some unforeseen error prevents progress');
insert into t_dvs_status (id,name,description) values
	 (9,'Rejected','Agent refuses to process this request, probably because it does not know how');
insert into t_dvs_status (id,name,description) values
	 (10,'Indeterminate','Status not known, maybe no files to test?');

create table t_dvs_test
 (id		integer not null,
  name		varchar2(30),
  description	varchar2(1000),
  --
  constraint pk_dvs_test primary key(id),
  --
  constraint uq_dvs_test_name unique(name),
  constraint uq_dvs_test_description unique(description)
 );
insert into t_dvs_test (id,name,description)
	 values (1,'size','filesize check on storage namespace');
insert into t_dvs_test (id,name,description)
	 values (2,'migration','migration-status check on storage namespace');
insert into t_dvs_test (id,name,description)
	 values (3,'cksum','checksum validation on physical file');

create sequence seq_dvs_block;
create table t_dvs_block
 (id		integer not null,
  block		integer not null,
  node		integer not null,
  test		integer not null,
  n_files	integer default 0 not null,
  time_expire	integer not null,
  priority	integer default 16384 not null,
  use_srm	char(1) default 'n' not null,
  --
  constraint pk_dvs_block primary key(id),
  --
  constraint fk_dvs_block_node
    foreign key (node) references t_adm_node(id)
    on delete cascade,
--  constraint fk_dvs_block_block
--    foreign key (block) references t_dps_block(id)
--    on delete cascade,
  constraint fk_dvs_block_test
    foreign key (test) references t_dvs_test(id)
    on delete cascade,
  constraint ck_dvs_block_use_srm check (use_srm in ('y','n'))
 );

alter table t_dvs_block add constraint fk_dvs_block_block
  foreign key (block) references t_dps_block(id)
  on delete cascade disable;

create sequence seq_dvs_file;
create table t_dvs_file
 (id		integer not null,
  request	integer not null,
  fileid	integer not null,
  time_queued	float,
  --
  constraint pk_dvs_file primary key(id),
  --
  constraint uq_dvs_file unique(request,fileid),
  --
  constraint fk_dvs_file_request
    foreign key (request) references t_dvs_block(id)
    on delete cascade,
  constraint fk_dvs_file_file
    foreign key (fileid) references t_dps_file(id)
    on delete cascade
 );

create sequence seq_dvs_file_result;
create table t_dvs_file_result
 (id		integer not null,
  request	integer not null,
  fileid	integer not null,
  time_reported	float   not null,
  status	integer not null,
  --
  constraint pk_dvs_file_result primary key (id),
  --
  constraint fk_dvs_file_result_request
    foreign key (request) references t_dvs_block(id)
    on delete cascade,
  constraint fk_dvs_file_result_file
    foreign key (fileid) references t_dps_file(id)
    on delete cascade
 );

create table t_status_block_verify
 (id		integer not null,
  block		integer not null,
  node		integer not null,
  test		integer not null,
  n_files	integer default 0 not null,
  n_tested	integer default 0 not null,
  n_ok		integer default 0 not null,
  time_reported	float   default 0 not null,
  status	integer default 0 not null,
  --
  constraint pk_status_block_verify primary key(id),
  --
  constraint fk_status_block_verify_node
    foreign key (node) references t_adm_node(id)
    on delete cascade,
--  constraint fk_status_block_verify_block
--    foreign key (block) references t_dps_block(id)
--    on delete cascade,
  constraint fk_status_block_verify_test
    foreign key (test) references t_dvs_test(id)
    on delete cascade
 );

alter table t_status_block_verify add constraint fk_status_block_verify_block
  foreign key (block) references t_dps_block(id)
  on delete cascade disable;

-- create indices
create index ix_dvs_block_block on t_dvs_block(block);
create index ix_dvs_block_node on t_dvs_block(node);
create index ix_dvs_block_test on t_dvs_block(test);
create index ix_dvs_file_file on t_dvs_file(fileid);
create index ix_dvs_file_result_file on t_dvs_file_result(fileid);
create index ix_dvs_file_result_request on t_dvs_file_result(request);
create index ix_status_block_verify_node on t_status_block_verify(node);
create index ix_status_block_verify_test on t_status_block_verify(test);
