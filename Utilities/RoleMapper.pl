#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Data::Dumper;
use PHEDEX::Core::SQLPLUS;
use Clone qw / clone /;
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

my ($roleMap,$schema,%schemas,$s,$packages,$p,$tables,$t,$dml,$d,$columns,@columns,$c,$roles,$role,$r);
my ($help,$verbose,$debug,$dumpRoleMap,$listRoles,$listSchemas,$allRoles,$grantee,%rights,%dmlMap);
my ($Roles,$Role,$Schema,@comments,%default,%knownTables,$sql,$dbparam,$script);
$roleMap = 'RoleMap.txt';
GetOptions(
            "help"        => \$help,
            "map=s"       => \$roleMap,
            "role=s@"     => \$Roles,
            "schema=s"    => \$Schema,
            "db=s"        => \$dbparam,
            "dumpRoleMap" => \$dumpRoleMap,
            "allRoles"    => \$allRoles,
            "listSchemas" => \$listSchemas,
            "listRoles"   => \$listRoles,
            "grantee=s"   => \$grantee,
            "verbose"     => \$verbose,
            "debug"       => \$debug,
          );

if ( @ARGV ) {
  warn "Unrecognised arguments: ",join(', ',@ARGV),"\n";
  usage();
}
$help && usage();
%dmlMap = (
            'add_partition'   => 'alter table',
            'drop_partition'  => 'alter table',
          );

sub readRoleMap() {
  my ($inSchema,$line,@packages);
  $inSchema = 0;
  open RM, "<$roleMap" or die "$roleMap: $!\n";
  while ( <RM> ) {
    s%^\s+%%;
    s%\s+$%%;

    if ( m%^#% ) {
      push @comments,$_;
      next;
    }
    s%#.*$%%;

    if ( m%^Schema\s+(\S+)% ) {
      $inSchema=1;
      $schema = $1;
      $schemas{$schema} = {};
      $s = $schemas{$schema};
      $verbose && print "-- Found schema $schema\n";
      next;
    }

#   Deal with ^Package Role$
    if ( m%::% or m%/% or m%^All_Agents% ) {
      if ( m%^(\S+)\s+(\S+)$% ) {
        $packages = $1;
        $r = $2;
        if ( $r =~ m%,% ) {
          die "Multiple default roles ($r) for a package/tool ($packages) is logically impossible\n";
        }
        if ( $r !~ m%^[A-Z][A-Za-z_\-)]+$% ) {
          die "Malformed role '$r' in '$_'\n";
        }
        @packages = split(',',$packages);
        foreach $p ( @packages ) {
          $verbose && print "-- Default role $r for package/tool $p\n";
          $default{$schema}{$p} = $r;
          $s->{$p} = {};
        }
      } else {
        foreach $p ( split(',',$_) ) {
          $verbose && print "-- Found package/tool $p\n";
          $s->{$p} = {};
        }
      }
      next;
    }

#   Deal with table entries
    if ( m%^(\S+)\s+(\S+)(\s+(\S+))?$% ) {
      $tables = $1;
      $dml    = $2;
      $roles  = $4;
      $line = $_;
      undef @columns;
      @columns = split(',',$1) if $dml =~ s%\((.*)\)%%;
      foreach $t ( split(',',$tables) ) {
        if ( $t !~ m%^t_[a-z,0-9,_]+$% ) {
          if ( $t ne 'no_such_table' ) {
            die "Malformed table name($t) in '$line'\n";
          }
        }
        $knownTables{$t} = 1;
        foreach $d ( split(',',$dml) ) {
          foreach $p ( @packages ) {
            $roles = $default{$schema}{$p} unless defined $roles;
            foreach $r ( split(',',$roles) ) {
              if ( $r !~ m%^[A-Z][A-Za-z_\-)]+$% ) {
                die "Malformed role '$r' in '$_'\n";
              }
              if ( $d !~ m%^(select|insert|update|delete|flashback|add_partition|drop_partition)$% ) {
                die "Unknown DML($d) in '$line'\n";
              }
              if ( @columns ) {
                map { $s->{$r}{$t}{$d}{$_}++ } @columns;
                $verbose && print "-- package=$p, role=$r, table=$t, dml=$d(",join(',',sort @columns),")\n";
              } else {
                $verbose && print "-- package=$p, role=$r, table=$t, dml=$d\n";
                $s->{$r}{$t}{$d}++;
              }
            }
          }
        }
      }
    }
  }
}

sub getRoleList {
  my ($all) = @_;
  $schemas{$Schema}{Nobody} = 1;
  if ( $all ) {
    return map { s%_% %g; "'$_'" } sort keys %{$schemas{$Schema}};
  } else {
    return map { s%_% %g; "'$_'" } sort grep { !/[:\/]/ } keys %{$schemas{$Schema}};
  }
}

sub getRole {
  my ($_r) = @_;
  $_r =~ s% %_%g;
  $_r =~ s%-%_%g;
  $_r = lc $_r;
  my $x;
  map { $x->{lc $_} = $_ } keys %{$schemas{$Schema}};
  $_r = $x->{$_r};
  return undef unless defined $_r;
  return ($_r,$schemas{$Schema}{$_r});
}

# Setup
readRoleMap();
$debug && print "-- Default: ",Dumper(\%default),"\n";

# assign $s to the default schema, or to all schemas. This is needed to handle dumpRoleMap correctly,
# i.e. the case that the Schema is specified or not.
$s = \%schemas;
if ( $Schema ) { $s = $s->{$Schema}; }

# Handle --dumpRoleMap
if ( $dumpRoleMap ) {
  if ( $Schema ) {
    print "Dumping role map for schema $Schema\n";
  }
  print "Schemas: ",Dumper($s),"\n";
  exit 0;
}

# Deduce default Schema, or validate given Schema
if ( $Schema ) {
  die "No such schema '$Schema'.\nKnown schemas are: ",join(', ',sort keys %schemas),"\n" unless defined $s;
} else {
  $Schema = (sort keys %schemas)[-1];
  print "Using schema=$Schema\n";
  $s = $schemas{$Schema};
}

# Handle --listSchemas
if ( $listSchemas ) {
  print "Known schemas are: ",join(', ',sort keys %schemas),"\n";
  exit 0;
}

# Handle --listRoles
if ( $listRoles || $allRoles ) {
  print "Roles in schema $Schema: ",join(', ',getRoleList($allRoles)),"\n";
  exit 0;
}

sub merge_hash {
  my ($h,$g) = @_;
  if ( ref($h) ne 'HASH' && ref($g) ne 'HASH' ) {
    return $h;
  }
  my $r = clone $h;

  foreach ( keys %{$g} ) {
    if ( exists $h->{$_} ) {
      $r->{$_} = merge_hash($h->{$_},$g->{$_});
    } else {
      $r->{$_} = clone $g->{$_};
    }
  }
  return $r;
}

if ( $dbparam ) {
  open OUT, '>',\$script;
} else {
  $script = 'grant-' . $grantee . '.sql';
# print "Writing output to $script\n";
  open OUT, ">$script" or die "open: $!\n";
}
# Function to revoke existing rights first...
$grantee && print OUT <<EOF;
set linesize 1000;
set serveroutput on;

declare
  cursor table_cursor is
    select table_name from user_tables order by table_name;
  cursor sequence_cursor is
    select sequence_name from user_sequences order by sequence_name;
  user varchar2(30);
begin
  user := '$grantee';
  dbms_output.put_line('Revoke access-rights to tables');
  for table_rec in table_cursor
  loop
    execute immediate 'revoke all on  ' || table_rec.table_name || ' from ' || user;
    dbms_output.put_line('revoke access to ' || table_rec.table_name);
  end loop;

-- now grant access to sequences
  dbms_output.put_line('Grant access-rights to sequences');
  for sequence_rec in sequence_cursor
  loop
    execute immediate 'grant select, alter on ' || sequence_rec.sequence_name || ' to ' || user;
    dbms_output.put_line('granted select,alter on ' || sequence_rec.sequence_name);
  end loop;

-- now grant read access to all tables
EOF

# Validate given role(s)
if ( $Roles ) {
  my ($correctRole,$correctRoles,%Roles);
  print "Using Roles: ",join(', ',@{$Roles}),"\n";
  $r = {};
  map { s% %_%g; s%-%_%g; $Roles{$_} = 1 } @{$Roles};
  if ( defined($Roles{'site_agent'} || $Roles{'central_agent'}) ) {
    $Roles{all_agents} = 1;
  }
  foreach $Role ( keys %Roles ) {
    if ( lc $Role eq 'nobody' ) {
      push @{$correctRoles}, 'Nobody';
      next;
    }
    ($correctRole,$s) = getRole($Role);
    die "No such role '$Role' in schema $Schema.\nKnown roles are: ",
         join(', ',getRoleList($listRoles)),
        "\n" unless defined $s;
    push @{$correctRoles}, $correctRole;
    $debug && print "Role='$correctRole', Schema=$Schema: ",Dumper($s),"\n";
    $r = merge_hash($r,$s);
  }
  $Roles = $correctRoles;
} else {
  die "No --role argument given, I don't know who you want to be mapped to\n";
}

# Now add select access to all the tables, for everyone...
foreach ( keys %knownTables ) {
  $r->{$_}{select} = 1;
}
# Now $r points to the right schema for the given role
if ( !$grantee ) {
  print "No --grantee given, nothing more to do!\n";
  exit 0;
}

# Generate grant statements for $grantee!
print OUT "  dbms_output.put_line('Assigning access-rights to tables');\n";
foreach $t ( sort keys %{$r} ) {
  next if $t eq 'no_such_table';
  $verbose && print "Table=$t\n";
  %rights = ();
  foreach $d ( keys %{$r->{$t}} ) {
    if ( $d eq 'update' ) {
      @columns = sort keys %{$r->{$t}{$d}};
      $verbose && print "table=$t, dml='$d', columns=(",join(',',sort @columns),")\n";
      $rights{"$d(".join(',',@columns).')'}++;
      undef @columns;
    } else {
      $verbose && print "table=$t, dml='$d'\n";
      $rights{$dmlMap{$d} or $d}++;
    }
  }
  $sql = 'grant ' . join(', ',sort keys %rights) . " on $t";
  print OUT "  dbms_output.put_line('$sql');\n";
  print OUT "  execute immediate '$sql TO ' || user;\n";
}

print OUT "end;\n/\n\n";
close OUT;
if ( $dbparam ) {
  sqlplus($dbparam,$script,1);
} else {
  print "SQL script written to $script\n";
}
