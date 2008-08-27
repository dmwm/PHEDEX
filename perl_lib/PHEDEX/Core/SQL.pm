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

=item select_scalar($query,%param)

returns a scalar representing the result of the 
query, which should select a single value from the database (e.g, C<'select 
count(*) from t_dps_file'>).

=item select_single($query,%param)

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

=item select_hash($query,$key,%param)

as select_single, but returns an array of hash references instead, so more 
complex data can be returned.

=over

C<$key> must be the name of a column (uppercase!) returned by the query, which
is used as the hash key for the returned data.

=back

=item execute_sql($query,%param)

This will execute the sql statement C<$query> with the bind parameters 
C<%param>, using L<PHEDEX::Core::DB::dbexec|PHEDEX::Core::DB/dbexec>. First,
however, it checks the sql 
statement for any 'like' clauses, and if they are present it will 1) 
correctly escape the bind parameters (replace '_' with '\\_') and add the 
"escape '\\'" declaration to the sql statement. Without this, the 
underscore is interpreted as a single-character wildcard by Oracle.

=item getTable($table,$key,@fields)

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

=item getBuffersFromWildCard(@nodes)

C<@nodes> is an array of node-name expressions, with '%' as the wildcard. 
This function returns a hashref with an entry for each node whose name 
matches any of the array entries, case-insensitive. Each returned entry 
has subkeys for the node NAME and TECHNOLOGY.

=item getLFNsFromBlocks(@block)

Return the LFNs of files in all blocks in t_dps_block where the block name
is LIKE any of C<@block>

=item getSiteReplicas($se_name)

Return the replicas (LFNs) of a storage element.

=item getBlocksFromLFNs(@lfn)

Return the block IDs of all blocks containing files with names LIKE any of
C<@lfn>

=item getDatasetsFromBlocks(@block)

Return the dataset names of all datasets containing blocks with names LIKE
any of C<@block>

=item getBlocksFromDatasets(@dataset)

Return the block names of all blocks contained in datasets with names LIKE
any of C<@dataset>

=item getLFNsFromWildCard($lfn)

Return the LFNs of all files with names LIKE C<$lfn>

=item getBlocksFromWildCard($block)

Return the block names of all blocks with names LIKE C<$block>

=item getBlocksFromIDs(@id)

Return the name of the blocks with IDs in the set of C<@id>

=item getBlockIDRange($n_blocks, $min_block)

Return a range ($min, $max) of block IDs between which there will be $n_blocks.
Useful for iterating over all blocks in order to save memory.

=item getDatasetsFromWildCard($dataset)

Return the dataset names of all datasets with names LIKE C<$dataset>

=item getBlockReplicasFromWildCard($block,@nodes)

Return a ref to a hash of block NAME and number of FILES from
t_dps_block_replica, keyed by block-ID, where the block name is LIKE C<$block>
and the node is IN C<@nodes>. C<@nodes> is optional.

=item getDBSFromBlockID($block)

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
use base 'PHEDEX::Core::Logging';
use Carp;
use POSIX;

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
  map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
      } keys %params;
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
sub select_scalar
{
# Selection of a single value from the first column, returned as scalar.
  my ( $self, $query, %param ) = @_;
  my ($q,@r);

  $q = execute_sql( $self, $query, %param );
  @r = $q->fetchrow();
  return $r[0];
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
  if ( grep( $_ eq 'DBH',  keys %{$self} ) ) { $dbh = $self->{DBH}; }

  if ( wantarray )
  {
    ($q,$r) = &dbexec($dbh, $query, %param);
    return ($q,$r);
  }
  else
  {
    $q = &dbexec($dbh, $query, %param);
    return $q;
  }
}

#-------------------------------------------------------------------------------
sub execute_rollback
{
  my $self  = shift;
  my $dbh = $self;

# see execute_sql to see why I do this :-(
  if ( grep( $_ eq 'DBH',  keys %{$self} ) ) { $dbh = $self->{DBH}; }

# Do the rollback!
  $dbh->rollback();
}

#-------------------------------------------------------------------------------
sub execute_commit
{
  my $self  = shift;
  my $dbh = $self;

# see execute_sql to see why I do this :-(
  if ( grep( $_ eq 'DBH',  keys %{$self} ) ) { $dbh = $self->{DBH}; }

# Do the commit!
  $dbh->commit();
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
# Escape any strings with underscores for literal use in a "like" condition
# TODO:  does this belong in a more general "Utilities" package?
sub escape_sql_like
{
    return map { $_ =~ s%_%\\_%g; $_; } @_;
}

#-------------------------------------------------------------------------------
# Takes an array and switches all '*' to '%' and '?' to '_', for use in SQL "like" clause
sub glob_to_sql_like
{
    return map { $_ =~ tr/*?/%_/; $_; } @_;
}

#-------------------------------------------------------------------------------
# Takes an array and expands all arrayrefs in the array and expands them
# TODO:  does this belong in a more general "Utilities" package?
sub arrayref_expand
{
    my @out;
    foreach (@_) {
	if    (!ref $_)           { push @out, $_; }
	elsif (ref $_ eq 'ARRAY') { push @out, @$_; } 
	else { next; }
    }
    return @out;
}

#-------------------------------------------------------------------------------
# builts a filter with bind parameters for a single column
#
# parameters:
#   $operator   'and' or 'or'.  default is 'or' if undefined
#   $wild       if true, always use wildcards in the filter
#   $sql        the sql string to append the filter to
#   $binds      a hash ref of bind parameters
#   $column     the name of the column to filter on
#   @values     the values to filter for
#
# returns:  the bind parameter hash if an array is wanted
#           otherwise the modified $sql
#
# by default, each value is filtered by the '=' operator, unless $wild
# is specified, or the value contains a wildcard, in which case the
# 'like' operator will be used
#
# all '*' characters in @values are changed to the sql wildcard '%'
#
# @values can contain arrayrefs, in which case they will be expanded
# into the list
# 
# if a @values element begins with the '!' character, then the
# operator will be negated
sub build_filter
{
  my ($self,$operator,$wild,$sql,$binds,$column,@values) = @_;
  @values = glob_to_sql_like arrayref_expand @values;
  my $bname = $column;  $bname =~ s/\./_/; # name of bind parameter
  my $i = 1;
  my $op = '=';
  $$sql .= join(" $operator ", map { $op = ($_ =~ s/^!//) ? '!=' : '=';            # negate operator?
				     if ($wild || (!defined $wild && $_ =~ /%/)) { # wildcards?
					 $op =~ s/!/not /; $op =~ s/=/like/; 
				     } 
				     $binds->{':' . $bname . $i} = $_;             # set bind parameters
				     "$column $op :$bname" . $i++                  # set sql statement
				     } @values
	   );
  return %{$binds} if wantarray;
  return $$sql;
}

#-------------------------------------------------------------------------------
# builds a filter with bind parameters for multiple filter/column
# pairs which have multiple values for the filter
#
# parameters:
#   $sql      scalar reference to the sql to append the filter to
#   $binds    hash reference to the bind_var => value hash
#   $filters  hash reference to the filter_name => value_array hash
#   %sql_map  hash of filter_name => column_name
#
# returns:  if an array is wanted, then the array of individual filter sqls is returned
#           else an 'and' joined filter of filters is returned
#           if no filter could be made, returns undef
#
# looks for the $filters->{OPERATORS} hashref to determine whether to
# make the given filter_name an 'and' filter or an 'or' filter.
# Default is an 'or' filter.
#
# example:  &build_multi_filters ( $self, "select 1 from dual d where 1=1 and ",
#				  {}, { foo => [1, 2, 3], bar => "xyz" },
#                                 foo => d.foo, bar => d.bar );
#
# turns $sql to 
#
# select 1 from dual d where 1=1 and (( d.foo = :foo_1 or d.foo = :foo_2 or d.foo = foo_3)
#                                and ( d.bar = :bar_1 ))
# and $p becomes { ':foo_1' => 1, ':foo_2' => 2, 'foo_3' => 3, 'bar_1' => xyz }
sub build_multi_filters
{
    my ($self, $sql, $binds, $filters, %sql_map) = @_;
    $sql ||= "";

    my @filter_set;
    while (my ($filter, $column) = each %sql_map) {
	if (exists $filters->{$filter}) {
	    my $values = $filters->{$filter};
	    my $operator = $filters->{OPERATORS}->{$filter} || 'or';
	    push @filter_set, '('. build_filter($self, $operator, undef, undef, $binds, $column, $values) . ')';
	}
    }
    if (@filter_set) {
	$$sql .= join ' and ', @filter_set;
	return wantarray ? @filter_set : $sql;
    } else {
	return undef;
    }
}


#-------------------------------------------------------------------------------
sub filter_and_like
{
  my ($self,$s,$p,$k,@v) = @_;
  return build_filter($self, 'and', 1, $s, $p, $k, @v);
}

#-------------------------------------------------------------------------------
sub filter_or_like
{
  my ($self,$s,$p,$k,@v) = @_;
  return build_filter($self, 'or', 1, $s, $p, $k, @v);
}

#-------------------------------------------------------------------------------
sub filter_or_eq
{
  my ($self,$s,$p,$k,@v) = @_;
  return build_filter($self, 'or', 0, $s, $p, $k, @v);  @v = arrayref_expand(@v);
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
sub getSiteReplicas
{
  my $self = shift;
  my %p = ( ':se_name' => @_ );
  my $sql = "select distinct f.logical_name from t_dps_file f
              join t_dps_block b               on b.id = f.inblock
              left join t_dps_block_replica br on br.block = b.id and br.node_files = b.files
              left join t_xfer_replica xr      on xr.fileid = f.id
              join t_adm_node n                on n.id = br.node or n.id = xr.node
             where n.se_name = :se_name
             order by 1";

  my $r = select_single ( $self, $sql, %p );
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
sub getBlockIDRange
{
  my $self = shift;
  my ($n_blocks, $min_block_id) = @_;
  $n_blocks ||= POSIX::INT_MAX;
  $min_block_id ||= 0;
  my $sql = qq{ select min(id) min_block, max(id) max_block from
		  (select * from (select id from t_dps_block where id >= :min_block order by id)
		   where rownum <= :n_blocks) };
  my $q = execute_sql ( $self, $sql, ':min_block' => $min_block_id, ':n_blocks' => $n_blocks );
  return $q->fetchrow();
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
  my $self = shift;
  my ($h,$block,@nodes,$complete);
  $h = shift;
  if ( ref($h) eq 'HASH' )
  {
    @nodes = $h->{NODES};
    $block = $h->{BLOCK};
    $complete = $h->{COMPLETE_BLOCKS};
  }
  else
  {
    $self->Logmsg('getBlockReplicasFromWildCard: use of positional interface is deprecated, please use the named-argument interface instead');
    $block = $h;
    @nodes = @_;
  }
  my $sql = qq {select block, name, files from
                t_dps_block_replica br join t_dps_block b on br.block = b.id
                where name like :name };
  my %p = ( ':name' => $block );
  if ( @nodes )
  {
    $sql .= ' and (' .  filter_or_eq( $self, undef, \%p, 'node', @nodes ) . ')';
  }
  if ( $complete )
  {
    $sql .= " and br.node_files = b.files and b.is_open = 'n'";
  }

  my $r = select_hash( $self, $sql, 'BLOCK', %p );
  return $r;
}

#-------------------------------------------------------------------------------
sub getDbsFromName
{
    my ($self, $dbs_name) = @_;
    my %p;
    my $sql = "select * from t_dps_dbs where name = :dbs_name";
    $p{':dbs_name'} = $dbs_name;

    my $q = execute_sql( $self, $sql, %p );
    return $q->fetchrow_hashref();
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

#-------------------------------------------------------------------------------
sub getBlockIDsFromDatasetWildcard
{
    my ($self, $dbs, @dataset_patterns) = @_;
    return [] unless @dataset_patterns;

    my %p;
    my $sql = qq{ select b.id
		    from t_dps_dataset ds
		    join t_dps_block b on b.dataset = ds.id
		   where } . filter_or_like( $self, undef, \%p, 'ds.name', @dataset_patterns );

    if ($dbs) {
	$sql .= ' and ds.dbs = :dbs';
	$p{':dbs'} = $dbs;
    }

    my $r = select_single( $self, $sql, %p );

    return $r;
}

#-------------------------------------------------------------------------------
sub getDatasetIDsFromDatasetWildcard
{
    my ($self, $dbs, @dataset_patterns) = @_;
    return [] unless @dataset_patterns;

    my %p;
    my $sql = qq{ select ds.id
		    from t_dps_dataset ds
		   where } . filter_or_like( $self, undef, \%p, 'ds.name', @dataset_patterns );

    if ($dbs) {
	$sql .= ' and ds.dbs = :dbs';
	$p{':dbs'} = $dbs;
    }

    my $r = select_single( $self, $sql, %p );

    return $r;
}

#-------------------------------------------------------------------------------
sub getBlockIDsFromBlockWildcard
{
    my ($self, $dbs, @block_patterns) = @_;
    return [] unless @block_patterns;

    my %p;
    my $sql = qq{ select b.id
		    from t_dps_block b
		    join t_dps_dataset ds on ds.id = b.dataset
		   where } . filter_or_like( $self, undef, \%p, 'b.name', @block_patterns );

    if ($dbs) {
	$sql .= ' and ds.dbs = :dbs';
	$p{':dbs'} = $dbs;
    }

    my $r = select_single( $self, $sql, %p );

    return $r;
}

#-------------------------------------------------------------------------------
sub getBlockIDsFromDatasetIDs
{
    my ($self, @dataset_ids) = @_;
    return [] unless @dataset_ids;

    my %p;
    my $sql = qq{ select b.id
		    from t_dps_block b 
		   where } . filter_or_eq( $self, undef, \%p, 'b.dataset', @dataset_ids );

    my $r = select_single( $self, $sql, %p );

    return $r;
}

#-------------------------------------------------------------------------------
sub getNodeMap
{
    my ($self, %h) = @_;
    my $sql = qq{ select id, name from t_adm_node };
    my $map = {};
    my $q = execute_sql($self, $sql);
    while (my ($id, $name) = $q->fetchrow()) {
	$map->{$id} = $name;
    }
    return $map;
}

1;
