package PHEDEX::Core::SQL;
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
  my ( $self, $query, %param ) = @_;
  my ($q,@r);

  $q = $self->execute_sql( $query, %param );
  @r = map {$$_[0]} @{$q->fetchall_arrayref()};
  return \@r;
}

#-------------------------------------------------------------------------------
sub select_hash
{
  my ( $self, $query, $key, %param ) = @_;
  my ($q,$r);

  $q = $self->execute_sql( $query, %param );
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

# Try this for size: If I am an object with a DBH, assume that's the database
# handle to use. Otherwise, assume _I_ am the database handle!
  $dbh = $self->{DBH} ? $self->{DBH} : $self;

  if ( $query =~ m%\blike\b%i )
  {
    foreach ( keys %param ) { $param{$_} =~ s%_%\\_%g; }
    $query =~ s%like\s+(:[^\)\s]+)%like $1 escape '\\' %gi;
  }

  $q = &dbexec($self->{DBH}, $query, %param);
  return $q;
}

sub getTable
{
  my ($self,$table,$key,@fields) = @_;

  $key = 'ID' unless $key;
  @fields=('*') unless @fields;
  if ( defined($self->{T_Cache}{$table}) ) { return $self->{T_Cache}{$table}; }
  my $sql = "select " . join(',',@fields) . " from $table";
  return $self->{T_Cache}{$table} = $self->select_hash( $sql, $key, () );
}

1;
