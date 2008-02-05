package PHEDEX::Web::SQL;

=head1 NAME

PHEDEX::Web::SQL - encapsulated SQL for the web data service

=head1 SYNOPSIS

This package simply bundles SQL statements into function calls.
It's not a true object package as such, and should be inherited from by
anything that needs its methods.

=head1 DESCRIPTION

pending...

=head1 METHODS

=over

=item getTransferStatus($self)

returns a reference to an array of hashes with the following keys:
TIME_UPDATE, DEST_NODE, SRC_NODE, STATE, PRIORITY, FILES, BYTES.
Each hash represents the current amount of data queued for transfer
(has tasks) for a link given the state and priority

=over

=item *

C<$self> is an object with a DBH member which is a valid DBI database
handle. To call the routine with a bare database handle, use the 
procedural call method.

=back

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';
use Carp;

our @EXPORT = qw( );
our (%params);
%params = ( DBH	=> undef );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
## my $self  = ref($proto) ? $class->SUPER::new(@_) : {};
  my $self  = $class->SUPER::new(@_);

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


sub getTransferStatus
{
    my ($self, %h) = @_;
    my ($sql,$q,@r);
    
    %h = @_;
    
    $sql = qq{
    select
      time_update,
      nd.name dest_node, ns.name src_node,
      state, priority,
      files, bytes
    from t_status_task xs
      join t_adm_node ns on ns.id = xs.from_node
      join t_adm_node nd on nd.id = xs.to_node
     order by nd.name, ns.name, state
 };

    $q = execute_sql( $self, $sql, () );
    while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

    return \@r;
}

sub getNodes
{
    my ($self, %h) = @_;
    my ($sql,$q,%p,@r);

    $sql = qq{
        select n.name node_name,
	       n.id node_id,
	       n.se_name se_name,
	       n.kind, n.technology
          from t_adm_node n
       };

    $q = execute_sql( $self, $sql, %p );
    while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

    return \@r;
}

sub getBlockReplicas
{
    my ($self, %h) = @_;
    my ($sql,$q,%p,@r);

    $sql = qq{
        select b.name block_name,
	       b.id block_id,
               b.files block_files,
               b.bytes block_bytes,
               b.is_open,
	       n.name node_name,
	       n.id node_id,
	       n.se_name se_name,
               br.node_files replica_files,
               br.node_bytes replica_bytes,
               br.time_create replica_create,
               br.time_update replica_update,
	       case when b.is_open = 'n' and
                         br.node_files = b.files
                    then 'y'
                    else 'n'
               end replica_complete
          from t_dps_block_replica br
	  join t_dps_block b on b.id = br.block
	  join t_dps_dataset ds on ds.id = b.dataset
	  join t_adm_node n on n.id = br.node
	 where br.dest_files = b.files
	   and n.se_name is not null
       };

    # XXX Temp limit
    $sql .= " and rownum < :limit";
    $p{':limit'} = $h{limit} || 1000;

    if (exists $h{complete}) {
	if ($h{complete} eq 'n') {
	    $sql .= qq{ and (br.node_files != b.files or b.is_open = 'y') };
	} elsif ($h{complete} eq 'y') {
	    $sql .= qq{ and br.node_files = b.files and b.is_open = 'n' };
	}
    }

    if (exists $h{node}) {
	$sql .= ' and ('. filter_or_eq($self, undef, \%p, 'n.name', $h{node}) . ')';
    }

    if (exists $h{se}) {
	$sql .= ' and ('. filter_or_eq($self, undef, \%p, 'n.se_name', $h{se}) . ')';
    }

     if (exists $h{block}) {
	 $sql .= ' and ('. filter_or_like($self, undef, \%p, 'b.name', $h{block}) . ')';
     }

    if (exists $h{create_since}) {
	$sql .= ' and br.time_create >= :create_since';
	$p{':create_since'} = $h{create_since};
    }

    if (exists $h{update_since}) {
	$sql .= ' and br.time_update >= :update_since';
	$p{':update_since'} = $h{update_since};
    }

    $q = execute_sql( $self, $sql, %p );
    while ( $_ = $q->fetchrow_hashref() ) { push @r, $_; }

    return \@r;
}

1;
