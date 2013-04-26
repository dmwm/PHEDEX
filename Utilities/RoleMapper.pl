#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Data::Dumper;
use PHEDEX::Schema::RoleMap;

my ($roleMap,$schema,$roles);
my ($help,$verbose,$debug,$dumpRoleMap,$listRoles,$listSchemas,$grantee,$allRoles);
my ($Schema,$dbparam);

$roleMap = 'RoleMap.txt';
sub usage {
  die <<EOF;

 Usage: $0 {options}

 where {options} are:

 This script will take a database role name and the names of several
'PhEDEx roles' and produce the SQL statements necessary to grant those
PhEDEx roles to the database role.

 --role=s	the name(s) of the role(s) you want access to (e.g, 'Admin',
		'Data Manager'). The special role 'nobody' will be given
		read-only rights to the entire database
 --grantee=s	the name of the database role to receive these access rights
 --db=s		if given, execute the grants directly from this account
 --map=s	name of the rolemap file. Defaults to '$roleMap' in the
		current directory
 --listRoles	print a list of known roles
 --listSchemas	print a list of known schema versions
 --dumpRoleMap	guess...
 --schema	schema version to use. Default is to use the highest version
		in your lookup table.
 --help, --verbose, --debug, all obvious

 The lookup table is, by default, in Utilities/RoleMap.txt in your PhEDEx
installation.

EOF
}

Getopt::Long::Configure( 'pass_through' );
GetOptions(
            "help"        => \$help,
            "map=s"       => \$roleMap,
            "role=s@"     => \$roles,
            "schema=s"    => \$Schema,
            "db=s"        => \$dbparam,
            "dumpRoleMap" => \$dumpRoleMap,
#           "allRoles"    => \$allRoles,
            "listSchemas" => \$listSchemas,
            "listRoles"   => \$listRoles,
            "grantee=s"   => \$grantee,
            "verbose"     => \$verbose,
            "debug"       => \$debug,
          );

if ( @ARGV ) {
  warn "Unrecognised arguments: ",join(', ',@ARGV),"\n";
  warn "Use '--help' for help\n";
  exit 0;
}
$help && usage();

my $roleMapper = PHEDEX::Schema::RoleMap->new(
		  MAP     => $roleMap,
		  DBPARAM => $dbparam,
		  GRANTEE => $grantee,
		  VERBOSE => $verbose,
		  DEBUG   => $debug,
		);

if ( $dumpRoleMap ) {
  $roleMapper->dumpRoleMap();
  exit 0;
}

if ( $listSchemas ) {
  $roleMapper->listSchemas();
  exit 0;
}

if ( $listRoles || $allRoles ) {
  $roleMapper->listRoles($allRoles);
  exit 0;
}

print 'Schema is set to: ',$roleMapper->Schema(),"\n";

$roles = $roleMapper->validateRoles($roles);
print "Using role-set: ",join(', ',@{$roles}),"\n";

$roleMapper->openScript();
$roleMapper->revokeRights();
$roleMapper->grantAccessToSequences();
$roleMapper->grantAccessToObjects();
$roleMapper->closeScript();
exit 0;
