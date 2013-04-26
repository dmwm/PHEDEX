#!/usr/bin/env perl
use warnings;
use strict;
use PHEDEX::Core::DB;
use PHEDEX::Core::SQLPLUS;
use Getopt::Long;
my ($master,$dbparam,$scriptAdmin,$scriptUser,$self,$dbh,$type);
my ($help,$verbose,$sql,$sth,@h,%objects,$saveAdminScript);

$scriptUser = 'initialise_role_access';
Getopt::Long::Configure( 'pass_through' );
GetOptions(
	    'save-admin-script' => \$saveAdminScript,
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
			 commands to. Default is '$scriptUser-\$master-user.sql'.

 This script will read all table-names, sequence-names, etc from the account
specified in the --db argument, and write a sql script which will create
synonyms for them in a target account.

 You then log into that target account and run this script manually.

EOF
  exit 0;
}
if ( @ARGV ) {
  warn "Unrecognised arguments: ",join(', ',@ARGV),"\n";
  warn "Use '--help' for help\n";
  exit 0;
}
$help && usage();
$dbparam || usage();

$self = { DBCONFIG => $dbparam };
$dbh = &connectToDatabase($self);

# Validate arguments
$master = lc $self->{DBH_DBUSER};
$verbose && print "Using '$master' account as template\n";

open ADMIN, ">", \$scriptAdmin or die "open $scriptAdmin: $!\n";

$saveAdminScript = "initialise_role_access-$master-admin.sql" if $saveAdminScript;
$scriptUser .= '-' . $master . '-user.sql';
open USER, ">$scriptUser" or die "open $scriptUser: $!\n";
$master = uc($master);

# Build the map of objects
$sql = qq{ select object_name, object_type from user_objects
	     where object_type in ('TABLE','SEQUENCE','FUNCTION','PROCEDURE','VIEW')
	     order by object_name };
$sth = PHEDEX::Core::DB::dbexec($dbh,$sql);
while ( @h = $sth->fetchrow_array() ) {
  if ( $h[1] ne 'FUNCTION' ) {
    next unless $h[0] =~ m%^(T|SEQ|IX|FK|PK|UQ|SCHEMA|PROC|FUNC|V)_[A-Z0-9_]+%;
  }
  $objects{$h[1]}{$h[0]}++;
}
# Add the functions that are created here, they may not yet be known
foreach ( qw / proc_abort_if_admin / ) {
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
    print ADMIN "  dbms_output.put_line('  $_');\n";
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
  end if;
end;
/

quit;
EOPLSQL3

print USER <<EOPLSQL4;
set serveroutput on;

declare
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
  other_owner number;
begin
  $master.proc_abort_if_admin;
  select count(*) into other_owner from user_synonyms where table_owner != '$master';
  if other_owner > 0 then
    dbms_output.put_line('you have synonyms to other schemas. Aborting for safety');
    raise_application_error(-20002,'Will not create synonyms since synonyms to other schemas already exist');
  end if;
EOPLSQL4

# Remove functions/procedures that the user does not need a synonym for
#foreach ( qw / proc_abort_if_admin 
#	       proc_grant_basic_read_access / ) {
#  delete $objects{PROCEDURE}{uc $_};
#}
delete $objects{PROCEDURE}{PROC_GRANT_BASIC_READ_ACCESS};

# now create the synonyms
foreach $type ( qw / TABLE SEQUENCE FUNCTION PROCEDURE VIEW / ) {
  print USER "  dbms_output.put_line('Create synonyms for ",lc $type,"s');\n";
  foreach ( sort keys %{$objects{$type}} ) {
    print USER "  dbms_output.put_line('$_');\n";
    print USER "  execute immediate 'create synonym $_ for $master.$_';\n";
  }
}

print USER <<EOPLSQL5;
  select count(*) into total from user_synonyms where table_owner = '$master';
  dbms_output.put_line('Created ' || total || ' synonyms');
end;
/

quit;
EOPLSQL5

close USER;
print "User script saved to '$scriptUser'\n";
close ADMIN;

if ( $saveAdminScript ) {
  open OUT, ">$saveAdminScript" or die "open $saveAdminScript: $!\n";
  print OUT $scriptAdmin;
  close OUT;
  print "Admin script saved to '$saveAdminScript'\n";
} else {
  print STDOUT "About to execute Admin script\n";
  PHEDEX::Core::SQLPLUS::run( DBCONFIG => $dbparam, VERBOSE => 1, SCRIPT => $scriptAdmin );
}
$verbose && print "All done\n";
