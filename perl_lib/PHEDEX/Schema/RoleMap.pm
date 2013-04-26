package PHEDEX::Schema::RoleMap;
use strict;
use warnings;
use PHEDEX::Core::SQLPLUS;
use Data::Dumper;
use Clone qw / clone /;

our (%params,$OUT);
%params = (
		SCHEMA	=> undef,
		MAP	=> 'RoleMap.txt',
		DBPARAM	=> undef,
		GRANTEE	=> undef,
		VERBOSE	=> 0,
		DEBUG	=> 0,
	  );


sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = {};
  my %args = (@_);
  map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
      } keys %params;
  bless $self, $class;

  if ( $self->{MAP} ) {
    $self->readRoleMap();
    $self->Schema();
  }

  return $self;
}

sub openScript {
  my $self = shift;

  defined $self->{GRANTEE} or die "No 'grantee' given, won't be able to do much...\n";

  if ( $self->{DBPARAM} ) {
die "Not supported yet, sorry!\n";
    open $OUT, '>',\$self->{SCRIPT};
  } else {
    $self->{SCRIPT} = 'grant-' . $self->{GRANTEE} . '.sql';
    open $OUT, ">$self->{SCRIPT}" or die "open: $!\n";
    print $OUT 
	"set linesize 1000;\n",
	"set serveroutput on;\n\n";

  }
}

sub closeScript {
  my $self = shift;

  if ( $self->{DBPARAM} ) {
    sqlplus($self->{DBPARAM},$self->{SCRIPT},1);
  } else {
    print "SQL script written to $self->{SCRIPT}\n";
    close $OUT;
  }
}

sub readRoleMap() {
  my $self = shift;
  my ($inSchema,$line,@packages,@comments);
  my ($schema,$s,$packages,$p,$tables,$t,$dml,$d,$columns,@columns,$c,@roles,$role,$r);
  $inSchema = 0;
  open RM, "<$self->{MAP}" or die "$self->{MAP}: $!\n";
  while ( <RM> ) {
    print if $self->{DEBUG};
    if ( m%^#% ) {
      push @comments,$_;
      next;
    }

    s%#.*$%%;
    s%^\s+%%;
    s%\s+$%%;

    if ( m%^Schema\s+(\S+)% ) {
      $inSchema=1;
      $schema = $1;
      $self->{SCHEMAS}{$schema}{PACKAGES}{Nobody} = {};
      $self->{VERBOSE} && print "-- Found schema $schema\n";
      $s = $self->{SCHEMAS}{$schema};
      next;
    }

#   Deal with Package Roles
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
        $s->{ROLES}{$r} = {} unless defined $s->{ROLES}{$r};
        @roles = ( $r );
        @packages = split(',',$packages);
        foreach $p ( @packages ) {
          $self->{VERBOSE} && print "-- Default role $r for package/tool $p\n";
if ( defined $s->{PACKAGES}{$p}{$r} ) {
  die "PACKAGES entry already exists for p=$p, r=$r, in line '$_'\n";
}
          $s->{PACKAGES}{$p}{$r} = {};
        }
      } else {
        foreach $p ( split(',',$_) ) {
          $self->{VERBOSE} && print "-- Found package/tool $p\n";
          $s->{PACKAGES}{$p} = {};
        }
      }
      next;
    }

#   Deal with table entries
    if ( m%^(\S+)\s+(\S+)(\s+(\S+))?$% ) {
      $tables = $1;
      $dml    = $2;
      @roles  = split(',',$4) if $4;
      $line = $_;
      undef @columns;
      @columns = split(',',$1) if $dml =~ s%\((.*)\)%%;
      foreach $t ( split(',',$tables) ) {
        if ( $t !~ m%^t_[a-z,0-9,_]+$% && $t !~ m%^proc_[a-z,0-9,_]+$% ) {
          if ( $t ne 'no_such_table' ) {
            die "Malformed table name($t) in '$line'\n";
          }
        }

        push @{$s->{OBJECTS}}, $t;
        foreach $d ( split(',',$dml) ) {
          foreach $p ( @packages ) {
            @roles = keys %{$s->{PACKAGES}{$p}} unless @roles;
            foreach $r ( @roles ) {
              if ( $r !~ m%^[A-Z][A-Za-z_\-)]+$% ) {
                die "Malformed role '$r' in '$_'\n";
              }
              if ( $d !~ m%^(select|insert|update|delete|flashback|add_partition|drop_partition|execute)$% ) {
                die "Unknown DML($d) in '$line'\n";
              }
              if ( @columns && ( $d eq 'update' ) ) {
                map { $s->{ROLES}{$r}{$t}{$d}{$_}++ } @columns;
                $self->{VERBOSE} && print "-- package=$p, role=$r, object=$t, dml=$d(",join(',',sort @columns),")\n";
              } else {
                $self->{VERBOSE} && print "-- package=$p, role=$r, object=$t, dml=$d\n";
                $s->{ROLES}{$r}{$t}{$d}++;
              }
            }
          }
        }
#       Add select for everyone
        $s->{ROLES}{$r}{$t}{select}++ if $t =~ m%^t_%;
      }
    }
  }
}

sub getRoleList {
  my ($self,$all) = @_;
  if ( $all ) {
    return map { s%_% %g; "'$_'" } sort keys %{$self->{CURRENT}{ROLES}};
  } else {
    return map { s%_% %g; "'$_'" } sort grep { !/[:\/]/ } keys %{$self->{CURRENT}{ROLES}};
  }
}

sub getRole {
  my ($self,$rIn) = @_;
  my ($r,@r);
  $r = $rIn;
  $r =~ s% %_%g;
  $r =~ s%-%_%g;
  $r = lc $r;
  my $x;
  map { $x->{lc $_} = $_ } keys %{$self->{CURRENT}{ROLES}};
  @r = grep(/^$r/,keys %{$x});
  if ( scalar(@r) > 1 ) {
    die "Ambiguous role '$rIn'. Matches '",join("', '",@r),"'\n";
  }
  die "Unknown role '$rIn'\n" unless scalar(@r) == 1;
  return $x->{$r[0]};
}

sub merge_hash {
  my ($h,$g) = @_;
  if ( ref($h) ne 'HASH' && ref($g) ne 'HASH' ) {
    return $h;
  }
  my $r = clone $h;

  foreach ( keys %{$g} ) {
    if ( exists $h->{$_} ) {
      $r->{$_} = PHEDEX::Schema::Map::merge_hash($h->{$_},$g->{$_});
    } else {
      $r->{$_} = clone $g->{$_};
    }
  }
  return $r;
}

sub dumpRoleMap {
  my $self = shift;
  if ( $self->{SCHEMA} ) {
    print "Dumping role map for schema $self->{SCHEMA}\n";
  }
  print "Schemas: ",Dumper($self->{SCHEMAS}),"\n";
  exit 0;
}

sub listSchemas {
  my $self = shift;
  print "Known schemas are: ",join(', ',sort keys %{$self->{SCHEMAS}}),"\n";
}

sub listRoles {
  my ($self,$allRoles) = @_;
  my $roles = join(',',$self->getRoleList($allRoles));
  print "Roles in schema $self->{SCHEMA}: $roles\n";
}

sub Schema {
# Deduce default Schema, or validate given Schema
  my ($self,$schema) = @_;

  if ( $schema ) {
    die "No such schema '$schema'.\nKnown schemas are: ",join(', ',sort keys %{$self->{SCHEMAS}}),"\n"
      unless defined $self->{SCHEMAS}{$schema};
    $self->{SCHEMA} = $schema;
    $self->{CURRENT} = $self->{SCHEMAS}{$schema};
  } else {
    if ( !$self->{SCHEMA} ) {
      $self->{SCHEMA} = (sort keys %{$self->{SCHEMAS}} )[-1];
      $self->{CURRENT} = $self->{SCHEMAS}{$self->{SCHEMA}};
      $self->{VERBOSE} && print "Using schema=$self->{SCHEMA}\n";
    }
  }

  return $self->{SCHEMA};
}

sub validateRoles {
  my ($self,$roles) = @_;
  my ($r,$s,$correctRole,$correctRoles,%roles);

  die "No roles given, I don't know who you want to be mapped to\n" unless $roles;

  print "Using Roles: ",join(', ',@{$roles}),"\n";
  map { s% %_%g; s%-%_%g; $roles{$_} = 1 } @{$roles};

  foreach $r ( keys %roles ) {
    $correctRole = $self->getRole($r);
    die "No such role '$r' in schema $self->{SCHEMA}.\nKnown roles are: ",
         join(', ',$self->getRoleList(1)),
      "\n" unless defined $correctRole;
    if ( $correctRole eq 'nobody' ) {
      push @{$correctRoles}, 'Nobody';
      next;
    }
    push @{$correctRoles}, $correctRole;
    if ( $correctRole eq 'Central_Agent' || $correctRole eq 'Site_Agent' ) {
      push @{$correctRoles}, 'All_Agents';
    }
  }
  return $self->{ROLES} = $correctRoles;
}

sub revokeRights {
  my $self = shift;
  my $grantee = $self->{GRANTEE};

  $grantee && print $OUT <<EOF;
declare
-- revoke rights on tables and sequences
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
    dbms_output.put_line('revoke access to ' || table_rec.table_name);
    execute immediate 'revoke all on ' || table_rec.table_name || ' from ' || user;
  end loop;

  dbms_output.put_line('Revoke access-rights to sequences');
  for sequence_rec in sequence_cursor
  loop
    dbms_output.put_line('revoke access to ' || sequence_rec.sequence_name);
    execute immediate 'revoke all on ' || sequence_rec.sequence_name || ' from ' || user;
  end loop;

end;

EOF
}

sub grantAccessToSequences {
  my $self = shift;
  my $grantee = $self->{GRANTEE};

  $grantee && print $OUT <<EOF;
declare
-- grant access to sequences
  cursor table_cursor is
    select table_name from user_tables order by table_name;
  cursor sequence_cursor is
    select sequence_name from user_sequences order by sequence_name;
  user varchar2(30);
begin
  user := '$grantee';
  dbms_output.put_line('Grant access-rights to sequences');
  for sequence_rec in sequence_cursor
  loop
    execute immediate 'grant select, alter on ' || sequence_rec.sequence_name || ' to ' || user;
    dbms_output.put_line('granted select,alter on ' || sequence_rec.sequence_name);
  end loop;

end;

EOF
}

sub grantAccessToObjects {
  my $self = shift;
  my $grantee = $self->{GRANTEE};
  my (%rights,$d,$r,$s,$t,@columns,$sql,%dmlMap);

  $grantee && print $OUT <<EOF;
declare
-- grant access to tables
  cursor table_cursor is
    select table_name from user_tables order by table_name;
  user varchar2(30);
begin
  user := '$grantee';
  dbms_output.put_line('Grant access-rights to tables');
EOF

# Generate grant statements for $grantee!
  foreach $r ( sort @{$self->{ROLES}} ) {
    foreach $t ( sort keys %{$self->{CURRENT}{ROLES}{$r}} ) {
      next if $t eq 'no_such_table';
      %rights = ();
      foreach $d ( keys %{$self->{CURRENT}{ROLES}{$r}{$t}} ) {
        if ( $d eq 'update' ) {
          @columns = sort keys %{$self->{CURRENT}{ROLES}{$r}{$t}{$d}};
          $self->{VERBOSE} && print "object=$t, dml='$d', columns=(",join(',',sort @columns),")\n";
          $rights{"$d(".join(',',@columns).')'}++;
          undef @columns;
        } else {
          $self->{VERBOSE} && print "object=$t, dml='$d'\n";
          $rights{$dmlMap{$d} or $d}++;
        }
      }
      $sql = 'grant ' . join(', ',sort keys %rights) . " on $t";
      print $OUT "  dbms_output.put_line('$sql');\n";
      print $OUT "  execute immediate '$sql TO ' || user;\n";
    }
  }

  print $OUT "end;\n\n";
}

1;
