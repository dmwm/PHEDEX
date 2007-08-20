--- create sequence seq_dvs_status;
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

create sequence seq_dvs_test;
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

create sequence seq_dvs_block;
create table t_dvs_block
 (id		integer not null,
  block		integer not null,
  node		integer not null,
  test		integer not null,
  n_files	integer default 0 not null,
  time_expire	integer not null,
  priority	integer default 0 not null,
  --
  constraint pk_dvs_block primary key(id),
  --
  constraint fk_dvs_block_node
    foreign key (node) references t_adm_node(id)
    on delete cascade,
  constraint fk_dvs_block_block
    foreign key (block) references t_dps_block(id)
    on delete cascade,
  constraint fk_dvs_block_test
    foreign key (test) references t_dvs_test(id)
 );

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
    foreign key (request) references t_dvs_block(id),
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
    foreign key (request) references t_dvs_block(id),
  constraint fk_dvs_file_result_file
    foreign key (fileid) references t_dps_file(id)
    on delete cascade
 );

create sequence seq_status_block_verify;
create table t_status_block_verify
 (id		integer not null,
  block		integer not null,
  node		integer not null,
  test		integer not null,
  n_files	integer default 0 not null,
  n_tested	integer default 0 not null,
  files_ok	integer default 0 not null,
  time_reported	float   default 0 not null,
  status	integer default 0 not null,
  --
  constraint pk_status_block_verify primary key(id),
  --
  constraint fk_status_block_verify_node
    foreign key (node) references t_adm_node(id)
    on delete cascade,
  constraint fk_status_block_verify_block
    foreign key (block) references t_dps_block(id)
    on delete cascade,
  constraint fk_status_block_verify_test
    foreign key (test) references t_dvs_test(id)
 );
