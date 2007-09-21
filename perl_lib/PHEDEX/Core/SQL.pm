package PHEDEX::Core::SQL;

=head1 NAME

PHEDEX::Core::SQL - utilities to make use of SQL easier for PhEDEx software,
and for PhEDEx developers!

=head1 SYNOPSIS

This module is intended to encapsulate simple SQL queries used in many places
in PhEDEx, and to provide a few simple utility routines to make similar
encapsulation easy for other modules.

The functions can be called directly, in which case the first argument is 
always a valid DBI database handle. If the OO interface is used, the code
expects to find a valid DBI database handle in $self->{DBH}.

This module does not provide any means of connecting to the database itself,
that is still to be taken care of externally, however you see fit.

=head1 DESCRIPTION

You can use the procedural subroutine interface

  use PHEDEX::Core::SQL;
  my $dbh = # a valid database connection handle
  my $sql = qq / select * from t_adm_node where name like :name /;
  my %param = ( ':name' => 'T1_CERN_%' );
  my $key = 'ID';
  my $hash = PHEDEX::Core::SQL::select_hash( $dbh, $sql, $key, %param );
  foreach ( keys %{$href} )
  {
    print $href->{$_}->{NAME},' ',$href->{$_}->{TECHNOLOGY},"\n";
  }

  my @nodes = ('t1_cern_%','t2_%');
  my $nodes = PHEDEX::Core::SQL::expandNodeList($dbh,@nodes);
  print $nodes->{5}->{NAME};

or the OO interface, creating a PHEDEX::Core::SQL object

  use PHEDEX::Core::SQL;
  my $SQL = PHEDEX::Core::SQL->new( DBH => $dbh );
  my $href $SQL->select_hash( $sql, $key, %param );

  my $nodes = $SQL->expandNodeList(@nodes);

or inherit it in your agent code

  use PHEDEX::Hypothetical::Agent; # which inherits PHEDEX::Core::SQL;
  my $agent = PHEDEX::Hypothetical::Agent->new( ...parameters... );
  my $href  = $agent->select_hash( $sql, $key, %param );

  $nodes = $agent->expandNodeList(@nodes);

=head1 Function list

=head2 $self->select_single( $query, %param )

returns a reference to an array of values representing the result of the 
query, which should select a single column from the database (e.g, 'select 
id from t_adm_node').

=over

=item *

$self is (an object with a DBH member which is) a valid DBI database
handle.

=item *

$query is any valid SQL query selecting a single column, from however many 
tables with whatever clauses. If the query selects more than one column, 
only the first column is returned.

=item *

%param is the bind parameters for that query.

=back

=head2 $self->select_hash( $query, $key, %param )

as select_single, but returns an array of hash references instead, so more 
complex data can be returned.

=over

$key must be the name of a column (uppercase!) returned by the query, which
is used as the hash key for the returned data.

=back

=head2 $self->execute_sql( $query, %param )

This will execute the sql statement $query with the bind parameters 
%param, using PHEDEX::DB::dbexec. First, however, it checks the sql 
statement for any 'like' clauses, and if they are present it will 1) 
correctly escape the bind parameters (replace '_' with '\\_') and add the 
"escape '\\'" declaration to the sql statement. Without this, the 
underscore is interpreted as a single-character wildcard by Oracle.

=head2 $self->getTable( $table, $key, @fields )

This utility routine will read an entire table or view, or just some specific
columns from it, and store it as a hash of hashrefs in
$self->{T_Cache}{$table}, keyed by $key.

This is useful for caching tables such as t_dvs_status, which exists only to
hold the names, descriptions, and IDs of the status fields used in the block
consistency checking.

=over

=item *

$table is the name of any table or view, e.g, 't_dvs_status'

=item *

$key is the name of a column to use as the key for the returned hash. Typically
the tables' primary key, it defaults to 'ID'.

=item *

@fields is the list of fields to select from the table or view, defaulting to
all fields.

=back

If called multiple times for the same table it will return the same
hashref, regardless if the field list or key differ from previous calls.

The table is cached in the object calling this function. If called again 
for the same table from another object, the query is executed against the 
database again.

=head2 $self->expandNodeList( @nodes )

@nodes is an array of node-name expressions, with '%' as the wildcard. 
This function returns a hashref with an entry for each node whose name 
matches any of the array entries, case-insensitive. Each returned entry 
has subkeys for the node NAME and TECHNOLOGY.

=head1 EXAMPLES

Hopefully there will be a test module at some point...

=head1 BUGS

If you find one, please check first on the PhEDEx wiki
(L</https://twiki.cern.ch/twiki/bin/view/CMS/PhedexProjects>) and if it's
not covered there, report it on the PhEDEx Savannah, at
L</https://savannah.cern.ch/projects/phedex/>

=cut

#
# This package simply bundles SQL statements into function calls.
# It's not a true object package as such, and should be inherited from by
# anything that needs its methods.
#
use strict;
use warnings;

use UtilsDB;
use Carp;

our @EXPORT = qw( );
our (%params);
%params = (
		DBH	=> undef,
	  );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = {};
  my %args = (@_);
  map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
  bless $self, $class;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

#-------------------------------------------------------------------------------
sub select_single
{
# Selection of a single quantity from a column, returned as an array ref.
  my ( $self, $query, %param ) = @_;
  my ($q,@r);

# $q = $self->execute_sql( $query, %param );
  $q = execute_sql( $self, $query, %param );
  @r = map {$$_[0]} @{$q->fetchall_arrayref()};
  return \@r;
}

#-------------------------------------------------------------------------------
sub select_hash
{
# Selection of a set of quantities, returned as a hash ref.
  my ( $self, $query, $key, %param ) = @_;
  my ($q,$r);

# $q = $self->execute_sql( $query, %param );
  $q = execute_sql( $self, $query, %param );
  $r = $q->fetchall_hashref( $key );

  my %s;
  map { $s{$_} = $r->{$_}; delete $s{$_}{$key}; } keys %$r;
  return \%s;
}

#-------------------------------------------------------------------------------
sub execute_sql
{
  my ( $self, $query, %param ) = @_;
  my ($dbh,$q,$r);

#
# Try this for size: If I am an object with a DBH, assume that's the database
# handle to use. Otherwise, assume _I_ am the database handle!
#
# I have to do this perverse check, rather than test $self->{DBH} explicitly,
# because the DBI module croaks if I try it.
#
  $dbh = $self;
  if ( grep( /^DBH$/,  keys %{$self} ) ) { $dbh = $self->{DBH}; }

# Properly escape any strings with underscores if the SQL statement has a
# 'like' clause, and add the appropriate 'escape' declaration to it.
  if ( $query =~ m%\blike\b%i )
  {
    foreach ( keys %param ) { $param{$_} =~ s%_%\\_%g; }
    $query =~ s%\blike\b\s+(:[^\)\s]+)%like $1 escape '\\' %gi;
  }

  $q = &dbexec($dbh, $query, %param);
  return $q;
}

#-------------------------------------------------------------------------------
sub getTable
{
# Retrieve an entire table as a hash, keyed by 'ID' unless otherwise
# specified. Useful for sucking in tables like t_dvs_status, which exist
# only to hold status codes and their names and descriptions.
  my ($self,$table,$key,@fields) = @_;

  $key = 'ID' unless $key;
  @fields=('*') unless @fields;
  if ( defined($self->{T_Cache}{$table}) ) { return $self->{T_Cache}{$table}; }
  my $sql = "select " . join(',',@fields) . " from $table";
  return $self->{T_Cache}{$table} = $self->select_hash( $sql, $key, () );
}

#-------------------------------------------------------------------------------
sub expandNodeList
{
  my $self = shift;
  my ($sql,$r,%p,$node,%result);

   $sql = qq {select id, name, technology from t_adm_node
              where upper(name) like :node };
  foreach $node ( @_ )
  {
    %p = ( ":node" => uc $node );
    $r = select_hash( $self, $sql, 'ID', %p );
    map { $result{$_} = $r->{$_} } keys %$r;
  }
  return \%result;
}

1;
