set pagesize 0
set long 90000

-- execute dbms_metadata.set_transform_param (dbms_metadata.session_transform, 'STORAGE', true)
-- execute dbms_metadata.set_transform_param (dbms_metadata.session_transform, 'PRETTY', true)

execute dbms_metadata.set_transform_param (dbms_metadata.session_transform, 'CONSTRAINTS_AS_ALTER', true)
execute dbms_metadata.set_transform_param (dbms_metadata.session_transform, 'TABLESPACE', true)
execute dbms_metadata.set_transform_param (dbms_metadata.session_transform, 'SQLTERMINATOR', true)

select dbms_metadata.get_ddl ('TABLE', x.table_name) from user_tables x;
select dbms_metadata.get_ddl ('INDEX', x.index_name) from user_indexes x;
select dbms_metadata.get_ddl ('TRIGGER', x.trigger_name) from user_triggers x;
select dbms_metadata.get_ddl ('SEQUENCE', x.sequence_name) from user_sequences x;
select dbms_metadata.get_ddl ('SYNONYM', x.synonym_name) from user_synonyms x;

-- object_grant
-- default_role
-- role
-- role_grant

execute dbms_metadata.set_transform_param (dbms_metadata.session_transform, 'DEFAULT');