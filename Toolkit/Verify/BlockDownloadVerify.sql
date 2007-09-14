insert into t_dvs_test (id,name,description) values (1,'size','filesize check on storage namespace');
insert into t_dvs_test (id,name,description) values (2,'migration','migration-status check on storage namespace');
insert into t_dvs_test (id,name,description) values (3,'cksum','checksum validation on physical file');

insert into t_dvs_status (id,name,description) values (0,'None','Request exists, but has never been looked at');
insert into t_dvs_status (id,name,description) values (1,'OK','Success');
insert into t_dvs_status (id,name,description) values (2,'Fail','Failure');
insert into t_dvs_status (id,name,description) values (3,'Queued','Queued, waiting for a worker to run it');
insert into t_dvs_status (id,name,description) values (4,'Active','Active, being run as we speak!');
insert into t_dvs_status (id,name,description) values (5,'Timeout','Timed out waiting for the worker');
insert into t_dvs_status (id,name,description) values (6,'Expired','Not enough results returned in time');
insert into t_dvs_status (id,name,description) values (7,'Suspended','Waiting for operator intervention');
insert into t_dvs_status (id,name,description) values (8,'Error','Some unforeseen error prevents progress');
insert into t_dvs_status (id,name,description) values (9,'Rejected','Agent refuses to process this request, probably because it does not know how');
insert into t_dvs_status (id,name,description) values (10,'Indeterminate','Status not known, maybe no files to test?');
