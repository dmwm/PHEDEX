#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Data::Dumper;
use PHEDEX::Schema::AuthMap;

my ($authMap,$dbparam);
my ($help,$verbose,$debug);

$authMap = 'AuthMap.txt';
sub usage {
  die <<EOF;

 Usage: $0 {options}

 where {options} are:

 This script will verify that the DB accounts and roles declared in the
map file have the correct relationship in the database,

 --db=s		if given, execute the grants directly from this account
 --map=s	name of the authmap file. Defaults to '$authMap' in the
		current directory
 --help, --verbose, --debug, all obvious

 The lookup table is, by default, in Utilities/AuthMap.txt in your PhEDEx
installation.

EOF
}

Getopt::Long::Configure( 'pass_through' );
GetOptions(
            "help"        => \$help,
            "map=s"       => \$authMap,
            "db=s"        => \$dbparam,
            "verbose"     => \$verbose,
            "debug"       => \$debug,
          );

if ( @ARGV ) {
  warn "Unrecognised arguments: ",join(', ',@ARGV),"\n";
  warn "Use '--help' for help\n";
  exit 0;
}
$help && usage();

my $authMapper = PHEDEX::Schema::AuthMap->new(
		  MAP     => $authMap,
		  DBPARAM => $dbparam,
		  VERBOSE => $verbose,
		  DEBUG   => $debug,
		);

#if ( $dumpRoleMap ) {
#  $roleMapper->dumpRoleMap();
#  exit 0;
#}

print "All done!\n";
exit 0;
