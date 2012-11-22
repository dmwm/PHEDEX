#!/usr/bin/env perl
use warnings;
use strict;
use PHEDEX::Core::DB;
use Getopt::Long;
my ($master,$dbparam,$scriptAdmin,$scriptUser,$self,$dbh,$type);
my ($help,$verbose,$print,$sql,$sth,@h,%objects);

$scriptAdmin = $scriptUser = 'initialise_role_access';
$print = 1;
GetOptions(
	    'admin-script=s'	=> \$scriptAdmin,
	    'user-script=s'	=> \$scriptUser,
	    'db=s'		=> \$dbparam,
	    'help'		=> \$help,
	    'verbose'		=> \$verbose,
	  );

sub usage {
  print <<EOF;

 Usage: $0 <options>
 where <options> are:

 --db {string}		 the DBParam specification for the connection to the
			 database for the master schema
 --user-script {string}	 (optional) name of output file to write user SQL
			 commands to. Use '-' for stdout;
			 Default is '$scriptUser-\$master-user.sql'.
 --admin-script {string} (optional) name of output file to write admin SQL
			 commands to. Use '-' for stdout;
			 Default is to feed them directly to SQL*PLUS.

 This script will read all table-names, sequence-names, etc from the account
specified in the --db argument, and write a sql script which will create
synonyms for them in a target account.

 You then log into that target account and run this script manually.

EOF
  exit 0;
}
$help && usage();
$dbparam || usage();

$self = { DBCONFIG => $dbparam };
$dbh = &connectToDatabase($self);

# Validate arguments
$master = lc $self->{DBH_DBUSER};
$print && print "Using '$master' account as template\n";

if ( $scriptAdmin eq '-' ) {
  *ADMIN = *STDOUT;
  $print = 0;
} else {
  $scriptAdmin .= '-' . lc $master . '-admin.sql';
  open ADMIN, ">$scriptAdmin" or die "open $scriptAdmin: $!\n";
}

if ( $scriptUser eq '-' ) {
  *USER = *STDOUT;
  $print = 0;
} else {
  $scriptUser .= '-' . lc $master . '-user.sql';
  open USER, ">$scriptUser" or die "open $scriptUser: $!\n";
}
$master = uc($master);

# Build the map of objects
$sql = qq{ select object_name, object_type from user_objects
	     where object_type in ('TABLE','SEQUENCE','FUNCTION','PROCEDURE')
	     order by object_name };
$sth = PHEDEX::Core::DB::dbexec($dbh,$sql);
while ( @h = $sth->fetchrow_array() ) {
  if ( $h[1] ne 'FUNCTION' ) {
    next unless $h[0] =~ m%^(T|SEQ|IX|FK|PK|UQ|SCHEMA|PROC|FUNC)_[A-Z0-9_]+%;
  }
  $objects{$h[1]}{$h[0]}++;
}
# Add the functions that are created here, they may not yet be known
foreach ( qw / proc_abort_if_admin 
	       proc_grant_basic_read_access / ) {
  $objects{PROCEDURE}{uc $_}++;
}

print ADMIN <<EOPLSQL;
set serveroutput on;

create or replace procedure proc_abort_if_admin as
  current_user varchar2(30);
begin
  select user into current_user from dual;
  if current_user like '$master' then
    dbms_output.put_line('Do not run this from the admin account! ($master);');
    raise_application_error(-20001,'Do not run this procedure as $master!');
  end if;
end;
/

grant execute on proc_abort_if_admin to public;

EOPLSQL

print ADMIN <<EOPLSQL2;
create or replace procedure proc_grant_basic_read_access(user in varchar2) as
begin
  if user like '$master' then
    dbms_output.put_line('Do not run this for the admin account! ($master);');
    raise_application_error(-20002,'Do not run this procedure for $master!');
  end if;
EOPLSQL2

foreach $type ( qw / TABLE SEQUENCE FUNCTION PROCEDURE / ) {
  print ADMIN "  dbms_output.put_line('Grant access to ",lc $type,"s');\n";
  foreach ( sort keys %{$objects{$type}} ) {
#   print ADMIN "  dbms_output.put_line('  $_');\n";
    if ( $type eq 'FUNCTION' or $type eq 'PROCEDURE' ) {
      print ADMIN "  execute immediate 'grant execute on $_ to ' || user;\n";
    } else {
      print ADMIN "  execute immediate 'grant select on $_ to ' || user;\n";
    }
  }
}
print ADMIN <<EOPLSQL3;
end;
/

declare
  current_user varchar2(30);
begin
  select user into current_user from dual;
  if current_user not like '$master' then
    dbms_output.put_line('This should only be run from the admin account! ($master);');
    execute immediate 'drop procedure proc_abort_if_admin';
    execute immediate 'drop procedure proc_grant_basic_read_access';
    dbms_output.put_line('...procedures deleted, you do not need them here');
  else
    dbms_output.put_line('granting execute on proc_abort_admin to public');    
    execute immediate 'grant execute on proc_abort_if_admin to public';
  end if;
end;
/

EOPLSQL3

print USER <<EOPLSQL4;
create or replace procedure proc_drop_synonyms as
  cursor synonym_cur is
    select synonym_name from user_synonyms where table_owner = '$master';
  total number;
begin
  $master.proc_abort_if_admin;
  total := 0;
  for synonym_rec in synonym_cur
  loop
    execute immediate 'drop synonym ' || synonym_rec.synonym_name;
    total := total + 1;
  end loop;
  dbms_output.put_line('Dropped ' || total || ' synonyms');
end;
/

declare
  total number;
begin
  proc_drop_synonyms;
EOPLSQL4

foreach $type ( qw / TABLE SEQUENCE FUNCTION PROCEDURE / ) {
  print USER "  dbms_output.put_line('Create synonyms for ",lc $type,"s');\n";
  foreach ( sort keys %{$objects{$type}} ) {
#   print USER "  dbms_output.put_line('  $_');\n";
    print USER "  execute immediate 'create synonym $_ for $master.$_';\n";
  }
}

print USER <<EOPLSQL5;
  select count(*) into total from user_synonyms where table_owner = '$master';
  dbms_output.put_line('Created ' || total || ' synonyms');
end;
/

EOPLSQL5

close USER;
close ADMIN;
$print && print "All done\n";
