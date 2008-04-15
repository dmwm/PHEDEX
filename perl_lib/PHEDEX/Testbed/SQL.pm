package PHEDEX::Testbed::SQL;

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';

use Carp;

our @EXPORT = qw( );

# Probably will never need parameters for this object, but anyway...
our %params =
	(
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new(%params,@_);
  bless $self, $class;
  return $self;
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
sub insertSubscription
{
    my ($self,$h) = @_;

    my $sql = qq{ 
	insert into t_dps_subscription
        (dataset, block, destination,
	 priority, is_move, is_transient, time_create)
    };

    if ($h->{DATASET}) {
	$sql .= qq{ select ds.id, NULL, :node, :priority, :is_move, :is_transient, :time_create 
		      from t_dps_dataset ds where ds.name = :dataset };
    } elsif ($h->{BLOCK}) {
	$sql .= qq{ select NULL, b.id, :node, :priority, :is_move, :is_transient, :time_create 
			from t_dps_block b where b.name = :block };
    } else {
	die "DATASET or BLOCK required\n";
    }

    my %p = map { ':' . lc $_ => $h->{$_} } keys %{$h};

    my ($sth, $n);
    eval {
      ($sth, $n) = execute_sql( $self, $sql, %p );
    };
    $self->Fatal($@) if $@;

    return $n;
}

sub deleteSubscription
{
    my ($self,$h) = @_;

    my $sql = qq{ 
	delete from t_dps_subscription
    };

    if ($h->{DATASET}) {
        $self->Fatal("Have not written sql for deleting dataset subscription yet...");
#	$sql .= qq{ select ds.id, NULL, :node, :priority, :is_move, :is_transient, :time_create 
#		      from t_dps_dataset ds where ds.name = :dataset };
    } elsif ($h->{BLOCK}) {
	$sql .= qq{ where destination = :node and block =
		 ( select id from t_dps_block where name = :block ) };
    } else {
	die "DATASET or BLOCK required\n";
    }

    my %p = map { ':' . lc $_ => $h->{$_} } keys %{$h};

    my ($sth, $n);
    eval {
      ($sth, $n) = execute_sql( $self, $sql, %p );
    };
    $self->Fatal($@) if $@;

    return $n;
}

sub insertBlockDeletion
{
    my ($self,$h) = @_;

    my $sql = qq{ 
	insert into t_dps_block_delete
        (block, dataset, node, time_request) 
    };

    if ($h->{DATASET}) {
	$sql .= qq{ select b.id, b.dataset, :node, :time_request
		      from t_dps_block b
		      join t_dps_dataset ds on ds.id = b.dataset
		      where ds.name = :dataset };
    } elsif ($h->{BLOCK}) {
	$sql .= qq{ select b.id, b.dataset, :node, :time_request
		      from t_dps_block b
		     where b.name = :block };
    } else {
	die "DATASET or BLOCK required\n";
    }

    my %p = map { ':' . lc $_ => $h->{$_} } keys %{$h};

    my ($sth, $n);
    eval {
      ($sth, $n) = execute_sql( $self, $sql, %p );
    };
    $self->Fatal($@) if $@;

    return $n;
}

1;
