package PHEDEX::RequestAllocator::SQL;

=head1 NAME

PHEDEX::RequestAllocator::SQL - encapsulated SQL for evaluating requests
Checking agent.

=head1 SYNOPSIS

This package simply bundles SQL statements into function calls.
It's not a true object package as such, and should be inherited from by
anything that needs its methods.

=head1 DESCRIPTION

pending...

=head1 METHODS

=over

=item method1($args)

=back

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,

=cut

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

# Fetch basic transfer request information
# Options:
#   APPROVED : if true, only return approved nodes
#   NODES : an arrayref of nodes.  Only return transfers affecting those nodes
#   AFTER : only return requests created after this timestamp
#   WILDCARDS : if true, only return requests with wildcards in them
#   STATIC   : if true, only return static requets, if false only return expanding requests
sub getTransferRequests
{
    my ($self, %h) = @_;

    my %p;
    my @where;
    if (defined $h{APPROVED}) {
	push @where, 'rd.decision = '.($h{APPROVED} ? "'y'" : "'n'");
    }

    if (defined $h{PENDING}) {
	push @where, 'rd.request is '.($h{PENDING} ? '' : 'not ').'null';
    }

    if (defined $h{DEST_ONLY} && $h{DEST_ONLY}) {
	push @where, "rn.point = 'd'";
    }

    if (defined $h{SRC_ONLY} && $h{SRC_ONLY}) {
	push @where, "rn.point = 's'";
    }

    if (defined $h{STATIC}) {
	push @where, 'rx.is_static = '.($h{STATIC} ? "'y'" : "'n'");
    }
    if (defined $h{MOVE}) {
	push @where, 'rx.is_move = '.($h{MOVE} ? "'y'" : "'n'");
    }
    if (defined $h{DISTRIBUTED}) {
	push @where, 'rx.is_distributed = '.($h{DISTRIBUTED} ? "'y'" : "'n'");
    }
    if (defined $h{WILDCARDS}) {
	push @where, "rx.data like '%*%'";
    }
    if (defined $h{AFTER}) {
	push @where, "r.time_create > :after";
	$p{':after'} = $h{AFTER};
    }
    if (defined $h{NODES}) {
	my $dummy = '';
	push @where, '('. &filter_or_eq($self, \$dummy, \%p, 'rn.node', @{$h{NODES}}).')';
    }

    my $where = '';
    $where = 'where '.join(' and ', @where) if @where;

    my $sql = qq{
	select r.id, rt.name type, r.created_by creator_id, r.time_create, rdbs.name dbs,
               rx.priority, rx.is_move, rx.is_static, rx.is_distributed, rx.data,
	       n.name node, n.id node_id,
               rn.point, rd.decision, rd.decided_by, rd.time_decided
	  from t_req_request r
          join t_req_type rt on rt.id = r.type
          join t_req_dbs rdbs on rdbs.request = r.id
	  join t_req_xfer rx on rx.request = r.id
          join t_req_node rn on rn.request = r.id
          join t_adm_node n on n.id = rn.node
     left join t_req_decision rd on rd.request = rn.request and rd.node = rn.node
        $where 
      order by r.id
 };
    
    $self->{DBH}->{LongReadLen} = 10_000;
    $self->{DBH}->{LongTruncOk} = 1;
    
    my $q = &dbexec($self->{DBH}, $sql, %p);
    
    my $requests = {};
    while (my $row = $q->fetchrow_hashref()) {
	# request data
	my $id = $row->{ID};
	if (!exists $requests->{$id}) {
	    $requests->{$id} = { map { $_ => $row->{$_} } 
				 qw(ID TYPE CREATOR_ID TIME_CREATE DBS
				    PRIORITY IS_MOVE IS_STATIC IS_DISTRIBUTED
				    DATA) };
	    $requests->{$id}->{NODES} = {};
	}
	
	# nodes of the request
	my $node = $row->{NODE_ID};
	if ($node) {
	    $requests->{$id}->{NODES}->{$node} = { map { $_ => $row->{$_} }
						   qw(NODE NODE_ID POINT DECISION DECIDED_BY TIME_DECIDED) };
	}
    }
    
    return $requests;
}

# fetch basic deletion request information
# Options:
#   APPROVED : if true, only return approved nodes
#   NODES : an arrayref of nodes.  Only return deletions affecting those nodes
#   AFTER : only return requests created after this timestamp
#   WILDCARDS : if true, only return requests with wildcards in them
#   RETRANSFER : if true, only return retransfer deletions, if false only return permenant deletions
sub getDeleteRequests
{
    my ($self, %h) = @_;

    my %p;
    my @where;
    if (defined $h{APPROVED}) {
	push @where, 'rd.decision = '.($h{APPROVED} ? "'y'" : "'n'");
    }

    if (defined $h{PENDING}) {
	push @where, 'rd.request is '.($h{PENDING} ? '' : 'not ').'null';
    }

    if (defined $h{RETRANSFER}) {
	push @where, 'rx.rm_subscriptions = '.($h{RETRANSFER} ? "'n'" : "'y'");
    }

    if (defined $h{WILDCARDS}) {
	push @where, "rx.data like '%*%'";
    }
    if (defined $h{AFTER}) {
	push @where, "r.time_create > :after";
	$p{':after'} = $h{AFTER};
    }
    if (defined $h{NODES}) {
	my $dummy = '';
	push @where, '('. &filter_or_eq($self, \$dummy, \%p, 'rn.node', @{$h{NODES}}).')';
    }

    my $where = '';
    $where = 'where '.join(' and ', @where) if @where;

    my $sql = qq{
	select r.id, rt.name type, r.created_by creator_id, r.time_create, rdbs.name dbs,
               rx.rm_subscriptions, rx.data,
	       n.name node, n.id node_id,
               rn.point, rd.decision, rd.decided_by, rd.time_decided
	  from t_req_request r
          join t_req_type rt on rt.id = r.type
          join t_req_dbs rdbs on rdbs.request = r.id
	  join t_req_delete rx on rx.request = r.id
          join t_req_node rn on rn.request = r.id
          join t_adm_node n on n.id = rn.node
     left join t_req_decision rd on rd.request = rn.request and rd.node = rn.node
        $where 
      order by r.id
 };
    
    $self->{DBH}->{LongReadLen} = 10_000;
    $self->{DBH}->{LongTruncOk} = 1;
    
    my $q = &dbexec($self->{DBH}, $sql, %p);
    
    my $requests = {};
    while (my $row = $q->fetchrow_hashref()) {
	# request data
	my $id = $row->{ID};
	if (!exists $requests->{$id}) {
	    $requests->{$id} = { map { $_ => $row->{$_} } 
				 qw(ID TYPE CREATOR_ID TIME_CREATE DBS
				    RM_SUBSCRIPTIONS DATA) };
	    $requests->{$id}->{NODES} = {};
	}
	
	# nodes of the request
	my $node = $row->{NODE_ID};
	if ($node) {
	    $requests->{$id}->{NODES}->{$node} = { map { $_ => $row->{$_} }
						   qw(NODE NODE_ID POINT DECISION DECIDED_BY TIME_DECIDED) };
	}
    }
    
    return $requests;
}

sub getExistingRequestData
{
    my ($self, $id) = @_;

    

    my $datasets = select_single ( $self->{DBH},
				   qq{ select rds.dataset_id from t_req_dataset rds
					   where rds.dataset_id is not null
                                             and rds.request = :id },
				   ':id' => $id );

    my $blocks = select_single ( $self->{DBH},
				 qq{ select rb.block_id from t_req_block rb
					 where rb.block_id is not null
                                           and rb.request = :id },
				 ':id' => $id );

    return $datasets, $blocks;
}

#
sub addRequestData
{
    my ($self, $request, %h) = @_;
    my $type;
    $type = 'DATASET' if $h{DATASET};
    $type = 'BLOCK'   if $h{BLOCK};
    return undef unless $type;

    $self->Logmsg("Adding $type $h{$type} to request $request")
}


#
sub createSubscription
{
    my ($self, %h);
    my $type;
    $type = 'DATASET' if $h{DATASET};
    $type = 'BLOCK'   if $h{BLOCK};
    return undef unless $type && $h{NODE} && $h{REQUEST};
   
    $self->Logmsg("Adding subscription $type $h{$type}, node $h{NODE}, request $h{REQUEST}");
}


1;
