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

This module is likely to undergo some considerable evolution. This
documentation is as much an experiment into how to document with pod as it is
a true manual for the module.

=head1 DESCRIPTION

You can use the procedural subroutine interface, with a bare database 
handle

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
  my $nodes = PHEDEX::Core::SQL::getBufferFromWildCard($dbh,@nodes);
  print $nodes->{5}->{NAME};

or the OO interface, creating a PHEDEX::Core::SQL object

  use PHEDEX::Core::SQL;
  my $SQL = PHEDEX::Core::SQL->new( DBH => $dbh );
  my $href $SQL->select_hash( $sql, $key, %param );

  my $nodes = $SQL->getBufferFromWildCard(@nodes);

or inherit it in your agent code

  use PHEDEX::Hypothetical::Agent; # which inherits PHEDEX::Core::SQL;
  my $agent = PHEDEX::Hypothetical::Agent->new( ...parameters... );
  my $href  = $agent->select_hash( $sql, $key, %param );

  $nodes = $agent->getBufferFromWildCard(@nodes);

=head1 METHODS

=over

=item C<< $self->select_single($query,%param) >>

returns a reference to an array of values representing the result of the 
query, which should select a single column from the database (e.g, C<'select 
id from t_adm_node'>).

=over

=item *

C<$self> is an object with a DBH member which is a valid DBI database
handle. To call the routine with a bare database handle, use the 
procedural call method.

=item *

C<$query> is any valid SQL query selecting a single column, from however many 
tables with whatever clauses. If the query selects more than one column, 
only the first column is returned.

=item *

C<%param> is the bind parameters for that query.

=back

=item C<< $self->select_hash($query,$key,%param) >>

as select_single, but returns an array of hash references instead, so more 
complex data can be returned.

=over

C<$key> must be the name of a column (uppercase!) returned by the query, which
is used as the hash key for the returned data.

=back

=item C<< $self->execute_sql($query,%param) >>

This will execute the sql statement C<$query> with the bind parameters 
C<%param>, using L<PHEDEX::Core::DB::dbexec|PHEDEX::Core::DB/dbexec>. First,
however, it checks the sql 
statement for any 'like' clauses, and if they are present it will 1) 
correctly escape the bind parameters (replace '_' with '\\_') and add the 
"escape '\\'" declaration to the sql statement. Without this, the 
underscore is interpreted as a single-character wildcard by Oracle.

=item C<< $self->getTable($table,$key,@fields) >>

This utility routine will read an entire table or view, or just some specific
columns from it, and store it as a hash of hashrefs in
C<< $self->{T_Cache}{$table} >>, keyed by C<$key>.

This is useful for caching tables such as t_dvs_status, which exists only to
hold the names, descriptions, and IDs of the status fields used in the block
consistency checking. Large tables, or tables that change rapidly, should
not be retrieved by this method.

=over

=item *

C<$table> is the name of any table or view, e.g. t_dvs_status.

=item *

C<$key> is the name of a column to use as the key for the returned hash. Typically
the tables' primary key, it defaults to 'ID'.

=item *

C<@fields> is the list of fields to select from the table or view, defaulting to
all fields.

=back

If called multiple times for the same table it will return the same
hashref, regardless if the field list or key differ from previous calls.

The table is cached in the object calling this function. If called again 
for the same table from another object, the query is executed against the 
database again. To force a refresh in a given object, simply delete
C<< $self->{T_Cache}{$table} >> and call the function again.

=item C<< $self->getBuffersFromWildCard(@nodes) >>

C<@nodes> is an array of node-name expressions, with '%' as the wildcard. 
This function returns a hashref with an entry for each node whose name 
matches any of the array entries, case-insensitive. Each returned entry 
has subkeys for the node NAME and TECHNOLOGY.

=item C<< $self->getLFNsFromBlocks(@block) >>

Return the LFNs of files in all blocks in t_dps_block where the block name
is LIKE any of C<@block>

=item C<< $self->getBlocksFromLFNs(@lfn) >>

Return the block IDs of all blocks containing files with names LIKE any of
C<@lfn>

=item C<< $self->getDatasetsFromBlocks(@block) >>

Return the dataset names of all datasets containing blocks with names LIKE
any of C<@block>

=item C<< $self->getBlocksFromDatasets(@dataset) >>

Return the block names of all blocks contained in datasets with names LIKE
any of C<@dataset>

=item C<< $self->getLFNsFromWildCard($lfn) >>

Return the LFNs of all files with names LIKE C<$lfn>

=item C<< $self->getBlocksFromWildCard($block) >>

Return the block names of all blocks with names LIKE C<$block>

=item C<< $self->getBlocksFromIDs(@id) >>

Return the name of the blocks with IDs in the set of C<@id>

=item C<< $self->getDatasetsFromWildCard($dataset) >>

Return the dataset names of all datasets with names LIKE C<$dataset>

=item C<< $self->getBlockReplicasFromWildCard($block,@nodes) >>

Return a ref to a hash of block NAME and number of FILES from
t_dps_block_replica, keyed by block-ID, where the block name is LIKE C<$block>
and the node is IN C<@nodes>. C<@nodes> is optional.

=item C<< $self->getDBSFromBlockID($block) >>

Return the DBS URL for the given block ID.

=back

=head1 EXAMPLES

Hopefully there will be a test module at some point...

=head1 BUGS

If you find one, please check first on the PhEDEx wiki
(L</https://twiki.cern.ch/twiki/bin/view/CMS/PhedexProjects>) and if it's
not covered there, report it on the PhEDEx Savannah, at
L</https://savannah.cern.ch/projects/phedex/>

=cut

use strict;
use warnings;

use PHEDEX::Core::DB;
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
  if ( ref($self) && defined($self->{T_Cache}{$table}) )
  { return $self->{T_Cache}{$table}; }

  my $sql = "select " . join(',',@fields) . " from $table";
  my $h = select_hash( $self, $sql, $key, () );
  if ( ref($self) ) { $self->{T_Cache}{$table} = $h; }
  return $h;
}

#-------------------------------------------------------------------------------
sub filter_and_like
{
  my ($self,$s,$p,$k,@v) = @_;
  my $i = 1;
  $$s .= join(' and ', map { $p->{':' . $k . $i} = $_; # bind parameters
			     "$k like :$k" . $i++      # sql statement
			   } @v
	   );
  return %{$p} if wantarray;
  return $$s;
}

#-------------------------------------------------------------------------------
sub filter_or_like
{
  my ($self,$s,$p,$k,@v) = @_;
  my $i = 1;
  $$s .= join(' or ', map { $p->{':' . $k . $i} = $_; # bind parameters
			    "$k like :$k" . $i++      # sql statement
			   } @v
	   );
  return %{$p} if wantarray;
  return $$s;
}

#-------------------------------------------------------------------------------
sub filter_or_eq
{
  my ($self,$s,$p,$k,@v) = @_;
  my $i = 1;
  $$s .= join(' or ', map { $p->{':' . $k . $i} = $_; # bind parameters
			    "$k = :$k" . $i++      # sql statement
			   } @v
	   );
  return %{$p} if wantarray;
  return $$s;
}

#-------------------------------------------------------------------------------
sub getLFNsFromBlocks
{
  my $self = shift;
  my %p;
  my $sql = "select logical_name from t_dps_file where inblock in
                (select id from t_dps_block where " .
                 filter_or_like( $self, undef, \%p, 'name', @_ ) . ')';
  my $r = select_single( $self, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksFromLFNs
{
  my $self = shift;
  my %p;
  my $sql = "select name from t_dps_block where id in
		(select unique inblock from t_dps_file where " .
		 filter_or_like( $self, undef, \%p, 'logical_name', @_ ) . ')';
  my $r = select_single( $self, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getDatasetsFromBlocks
{
  my $self = shift;
  my %p;
  my $sql = "select name from t_dps_dataset where id in
                (select dataset from t_dps_block where " .
		filter_or_like( $self, undef, \%p, 'name', @_ ) . ')';
  my $r = select_single( $self, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksFromDatasets
{
  my $self = shift;
  my %p;
  my $sql = "select name from t_dps_block where dataset in
                (select id from t_dps_dataset where " .
		filter_or_like( $self, undef, \%p, 'name', @_ ) . ')';
  my $r = select_single( $self, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getLFNsFromWildCard
{
  my $self = shift;
  my %p;
  my $sql = "select logical_name from t_dps_file where " .
		filter_or_like( $self, undef, \%p, 'logical_name', @_ );
  my $r = select_single( $self, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksFromWildCard
{
  my $self = shift;
  my %p;
  my $sql = "select name from t_dps_block where " .
		filter_or_like( $self, undef, \%p, 'name', @_ );
  my $r = select_single( $self, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBlocksFromIDs
{
  my $self = shift;
  my %p;
  my $sql = "select name from t_dps_block where " .
		filter_or_eq( $self, undef, \%p, 'id', @_ );
  my $r = select_single( $self, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getDatasetsFromWildCard
{
  my $self = shift;
  my %p;
  my $sql = "select name from t_dps_dataset where " .
		filter_or_like( $self, undef, \%p, 'name', @_ );
  my $r = select_single( $self, $sql, %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getBuffersFromWildCard
{ 
  my $self = shift;
#die "Tony has to fix this\n";
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

#-------------------------------------------------------------------------------
sub getBlockReplicasFromWildCard
{
  my ($self,$block,@nodes) = @_;
  my $sql = qq {select block, name, files from
                t_dps_block_replica br join t_dps_block b on br.block = b.id
                where name like :name };
  my %p = ( ':name' => $block );
  if ( @nodes )
  {
    $sql .= ' and (' .  filter_or_eq( $self, undef, \%p, 'node', @nodes ) . ')';
  }

  my $r = select_hash( $self, $sql, 'BLOCK', %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getDBSFromBlockIDs
{
  my $self = shift;
  my %p;
  my $sql = "select unique dbs.name from t_dps_block b
		join t_dps_dataset d on b.dataset = d.id
		join t_dps_dbs dbs on d.dbs = dbs.id
		where ";
  my $i=0;
  foreach ( @_ )
  {
    $sql .= ' or' if $i++;
    $sql .= " b.id = :bid$i ";
    $p{":bid$i"} = $_;
  }

  my $r = select_single( $self, $sql, %p );
  return $r;
}

1;
