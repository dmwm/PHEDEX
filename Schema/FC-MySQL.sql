-- Table structure for table 't_pfn'

CREATE TABLE t_pfn (
  pfname varchar(250) binary NOT NULL default '',
  guid varchar(40) binary default NULL,
  filetype varchar(250) binary default NULL,
  PRIMARY KEY  (pfname),
  KEY idxt_pfn (guid)
) TYPE=InnoDB;

-- Table structure for table 't_lfn'

CREATE TABLE t_lfn (
  lfname varchar(250) binary NOT NULL default '',
  guid varchar(40) binary default NULL,
  PRIMARY KEY  (lfname),
  KEY idxt_lfn (guid)
) TYPE=InnoDB;

-- Table structure for table 't_metaspec'

CREATE TABLE t_metaspec (
  colname varchar(250) binary NOT NULL default '',
  coltype varchar(40) binary default NULL,
  PRIMARY KEY  (colname)
) TYPE=InnoDB;

-- Table structure for table 't_meta'

CREATE TABLE t_meta (
  guid varchar(40) binary NOT NULL default '',
  Content blob,
  DBoid blob,
  DataType blob,
  FileCategory blob,
  Flags blob,
  dataset blob,
  jobid blob,
  owner blob,
  runid blob,
  PRIMARY KEY  (guid)
) TYPE=InnoDB;

-- CMS meta data schema

INSERT INTO t_metaspec VALUES ('Content','string');
INSERT INTO t_metaspec VALUES ('DBoid','string');
INSERT INTO t_metaspec VALUES ('DataType','string');
INSERT INTO t_metaspec VALUES ('FileCategory','string');
INSERT INTO t_metaspec VALUES ('Flags','string');
INSERT INTO t_metaspec VALUES ('dataset','string');
INSERT INTO t_metaspec VALUES ('jobid','string');
INSERT INTO t_metaspec VALUES ('owner','string');
INSERT INTO t_metaspec VALUES ('runid','string');

COMMIT;
