----------------------------------------------------------------------
-- Create sequences

create sequence t_adm_node_sequence
    increment by 1
    start with 1
    nomaxvalue
    nocycle
    cache 10;


create sequence t_directories_sequence
    increment by 1
    start with 1
    nomaxvalue
    nocycle
    cache 10;


----------------------------------------------------------------------
-- Create tables

create table t_adm_node (
    name    varchar(50)        not null,
    id          integer            not null,
  --
  constraint pk_adm_node
    primary key (id),
  constraint unique_adm_node__name
    unique (name)
);

create table t_directories (
    dir       varchar(1000)        not null,
    id          integer            not null,
  --
  constraint pk_directories
    primary key (id),
  constraint unique_dir
    unique (dir)
);

create table t_space_usage (
    timestamp     integer     not null,
    site_id       integer     not null, 
    dir_id        integer     not null,
    space         integer     not null,   
  --
  constraint pk_space_usage 
    primary key (site_id, dir_id, timestamp),
  --
  constraint fk_space_usage_dir_id 
    foreign key (dir_id) references t_directories (id),
  --
  constraint fk_space_usage_node_id
    foreign key (site_id) references t_adm_node (id)
);
