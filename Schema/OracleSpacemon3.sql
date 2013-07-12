----------------------------------------------------------------------
-- Create sequences

create sequence t_adm_node_sequence_3
    increment by 1
    start with 1
    nomaxvalue
    nocycle
    cache 10;


create sequence t_directories_sequence_3
    increment by 1
    start with 1
    nomaxvalue
    nocycle
    cache 10;


----------------------------------------------------------------------
-- Create tables

create table t_adm_node_3 (
    name    varchar(50)        not null,
    id          integer            not null,
  --
  constraint pk_adm_node_3
    primary key (id),
  constraint unique_adm_node_name_3
    unique (name)
);

create table t_directories_3 (
    dir       varchar(1000)        not null,
    id          integer            not null,
  --
  constraint pk_directories_3
    primary key (id),
  constraint unique_dir_3
    unique (dir),
  --
  constraint fk_directories_tag_id_3
    foreign key (tag_id) references t_data_tags_3 (id)
);

create table t_data_tags_3 (
    name       varchar(50)        not null,
    id          integer           not null,
  --
  constraint pk_data_tag_3
    primary key (id),
  constraint unique_tag_name_3
    unique (name)
);

create table t_space_usage_3 (
    timestamp     integer     not null,
    site_id       integer     not null, 
    dir_id        integer     not null,
    space         integer     not null,   
  --
  constraint pk_space_usage_3
    primary key (site_id, dir_id, timestamp),
  --
  constraint fk_space_usage_dir_id_3 
    foreign key (dir_id) references t_directories_3 (id),
  --
  constraint fk_space_usage_node_id_3
    foreign key (site_id) references t_adm_node_3 (id)
);
