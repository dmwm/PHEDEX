package PHEDEX::RequestAllocator::SQL;

=head1 NAME

PHEDEX::RequestAllocator::SQL - encapsulated SQL for evaluating requests

=head1 SYNOPSIS

This package simply bundles SQL statements into function calls.
It's not a true object package as such, and should be inherited from by
anything that needs its methods.

=head1 DESCRIPTION

pending...

=head1 METHODS

=over

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';

use PHEDEX::Core::Timing;

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

=pod

=item getTransferRequests($self, %args)

Fetch basic transfer request information.  TODO:  Document output format!

 Options:
  APPROVED    : if true, return approved; if false, return disapproved; if null, return either;
  PENDING     : if true, return pending nodes; if false, return decided; if null, return either;
  DEST_ONLY   : if true, return only destination nodes; if false or null, return either;
  SRC_ONLY    : if true, return only source nodes; if false or null, return either;
  STATIC      : if true, only return static requets, if false only return expanding requests
  MOVE        : if true, return move requests; if false, return copy requests; if null return either;
  DISTRIBUTED : if true, return dist. reqs; if false, return non-dist.; if null, return either;
  WILDCARDS   : if true, only return requests with wildcards in them
  AFTER       : only return requests created after this timestamp
  NODES       : an arrayref of nodes.  Only return transfers affecting those nodes
  REQUESTS    : an arrayref of request ids.  

=cut

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
    if (defined $h{REQUESTS}) {
	my $dummy = '';
	push @where, '('. &filter_or_eq($self, \$dummy, \%p, 'r.id', @{$h{REQUESTS}}).')';
    }


    my $where = '';
    $where = 'where '.join(' and ', @where) if @where;

    my $sql = qq{
	select r.id, rt.name type, r.created_by creator_id, r.time_create, rdbs.dbs_id, rdbs.name dbs,
               rx.priority, rx.is_move, rx.is_transient, rx.is_static, rx.is_distributed, rx.data,
	       n.name node, n.id node_id,
               rn.point, rd.decision, rd.decided_by, rd.time_decided,
	       rx.user_group, rx.is_custodial
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
				 qw(ID TYPE CREATOR_ID TIME_CREATE DBS_ID DBS
				    PRIORITY IS_MOVE IS_TRANSIENT IS_STATIC
				    IS_DISTRIBUTED IS_CUSTODIAL USER_GROUP
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

=pod

=item getDeleteRequests($self, %h)

Fetch basic deletion request information.

 Options:
  APPROVED    : if true, return approved; if false, return disapproved; if null, return either;
  PENDING     : if true, return pending nodes; if false, return decided; if null, return either;
  RETRANSFER  : if true, only return retransfer deletions, if false only return permenant deletions
  WILDCARDS   : if true, only return requests with wildcards in them
  AFTER       : only return requests created after this timestamp
  NODES       : an arrayref of nodes.  Only return deletions affecting those nodes
  REQUESTS    : an arrayref of request ids.  

=cut

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
    if (defined $h{REQUESTS}) {
	my $dummy = '';
	push @where, '('. &filter_or_eq($self, \$dummy, \%p, 'r.id', @{$h{REQUESTS}}).')';
    }

    my $where = '';
    $where = 'where '.join(' and ', @where) if @where;

    my $sql = qq{
	select r.id, rt.name type, r.created_by creator_id, r.time_create, rdbs.dbs_id, rdbs.name dbs,
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
				 qw(ID TYPE CREATOR_ID TIME_CREATE DBS_ID DBS
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

=pod

=item getExistingRequestData($self, $request, %args)

Returns arrayrefs of datasets and blocks (ids) attached to this request.

 Options:
   EXPAND_DATASETS : if true, expands datasets into block ids and returns them in the block array

=cut

sub getExistingRequestData
{
    my ($self, $request, %h) = @_;

    my $datasets = select_single ( $self->{DBH},
				   qq{ select rds.dataset_id from t_req_dataset rds
					   where rds.dataset_id is not null
                                             and rds.request = :id },
				   ':id' => $request );

    my $blocks = select_single ( $self->{DBH},
				 qq{ select rb.block_id from t_req_block rb
			 	      where rb.block_id is not null
                                        and rb.request = :id },
				 ':id' => $request );

    if ($h{EXPAND_DATASETS}) {
	my $ds_blocks = select_single ( $self->{DBH},
					qq{ select b.id
                                              from t_req_dataset rds
                                              join t_dps_block b on b.dataset = rds.dataset_id
                                             where rds.dataset_id is not null
					       and rds.request = :id } );
	push @$blocks, @{$ds_blocks};
    }
    
    return $datasets, $blocks;
}

=pod

=item addRequestData($self, $request, %args)

Adds a dataset or block to a request.

=cut

sub addRequestData
{
    my ($self, $request, %h) = @_;
    my $type;
    $type = 'DATASET' if $h{DATASET};
    $type = 'BLOCK'   if $h{BLOCK};
    return undef unless $type && $request;

    my $type_lc = lc $type;
    my $sql = qq{ insert into t_req_${type_lc}
		  (request, name, ${type_lc}_id)
                  select :request, name, id
                  from t_dps_${type_lc}
                  where id = :id };

    my ($sth, $n);
    ($sth, $n) = execute_sql( $self, $sql, ':request' => $request, ':id' => $h{$type} );

    return $n;
}

=pod

=item createSubscription($self, %args)

Creates a new subscription for a dataset or block.

Required:
 DATASET or BLOCK : the name or ID of a dataset or block
 REQUEST : request ID this is associated with
 DESTINATION : the destination node ID
 PRIORITY : priority
 IS_MOVE : if this is a move subscription
 IS_TRANSIENT : if this is a transient subscription
 TIME_CREATE : the creation time

TODO: Check that block subscriptions are not created where a dataset
      subscription exists?  BlockAllocator takes care of this, but it may be 
      unneccessary strain on that agent.

=cut

sub createSubscription
{
    my ($self, %h) = @_;;

    my $type;
    $type = 'DATASET' if defined $h{DATASET};
    $type = 'BLOCK'   if defined $h{BLOCK};
    if (!defined $type || (defined $h{DATASET} && defined $h{BLOCK})) {
	$self->Alert("cannot create subscriptioin:  DATASET or BLOCK must be defined");
	return undef;
    }

    my @required = qw(REQUEST DESTINATION PRIORITY IS_MOVE IS_TRANSIENT TIME_CREATE IS_CUSTODIAL);
    foreach (@required) {
	if (!exists $h{$_} || !defined $h{$_}) {
	    $self->Alert("cannot create subscription:  $_ not defined");
	    return undef;
	}
    }

#   Special case for USER_GROUP, which must exist but may be NULL
    if (!exists $h{USER_GROUP}) {
	$self->Alert("cannot create subscription:  USER_GROUP not defined");
	return undef;
    }

    foreach ( qw(IS_MOVE IS_TRANSIENT IS_CUSTODIAL) ) {
	next unless  $h{$_} =~ /^[0-9]$/;
	$h{$_} = ( $h{$_} ? 'y' : 'n' );
    }

    my $sql = qq{ 
	insert into t_dps_subscription
        (request, dataset, block, destination,
	 priority, is_move, is_transient, time_create,
	 is_custodial, user_group)
    };

    if ($h{$type} !~ /^[0-9]+$/) { # if not an ID, then lookup IDs from the name
	if ($type eq 'DATASET') {
            $h{USER_GROUP} = 'NULL' unless $h{USER_GROUP};
	    $sql .= qq{ select :request, ds.id, NULL, :destination, :priority, :is_move, :is_transient, :time_create } .
			", '$h{IS_CUSTODIAL}', $h{USER_GROUP} " . 
			qq{ from t_dps_dataset ds where ds.name = :dataset };
	} elsif ($type eq 'BLOCK') {
            $h{USER_GROUP} = 'NULL' unless $h{USER_GROUP};
	    $sql .= qq{ select :request, NULL, b.id, :destination, :priority, :is_move, :is_transient, :time_create } .
			", '$h{IS_CUSTODIAL}', $h{USER_GROUP} " . 
			qq{ from t_dps_block b where b.name = :block };
	}
    } else { # else we write exactly what we have
	$sql .= qq{ values (:request, :dataset, :block, :destination, :priority, :is_move, :is_transient, :time_create, :is_custodial, :user_group) };
    }

    my %p = map { ':' . lc $_ => $h{$_} } @required, qw(DATASET BLOCK USER_GROUP);

    my ($sth, $n);
    eval { ($sth, $n) = execute_sql( $self, $sql, %p ); };
    die $@ if $@ && !($h{IGNORE_DUPLICATES} && $@ =~ /ORA-00001/);

    return $n;
}


=pod

=item writeRequestComments($self, $request, $client, $comments, $time)

Writes a comment to the database, returning the comment id.

=cut

sub writeRequestComments
{
    my ($self, $rid, $client, $comments, $time) = @_;
    return undef unless ($rid && $client && $comments && $time);

    my $comments_id;
    execute_sql($self,
		qq[ insert into t_req_comments (id, request, comments_by, comments, time_comments)
		    values (seq_req_comments.nextval, :rid, :client, :comments, :time_comments)
		    returning id into :comments_id],
		':rid' => $rid, ':client' => $client, ':comments' => $comments, ':time_comments' => $time,
		':comments_id' => \$comments_id);

    return $comments_id;
}

=pod

=item addSubscriptionForRequest($self, $request, $node, $time)

Subscribe request data to $node for $request.  This DML ignores
duplicates but updates the parameters if there are duplicates.

=cut

sub addSubscriptionsForRequest
{
    my ($self, $rid, $node_id, $time) = @_;

    my ($sth, $rv) = &dbexec($$self{DBH}, 
     qq[ merge into t_dps_subscription s
         using
         (select r.id, :destination destination, rdata.dataset, rdata.block, 
                 rx.priority, rx.is_custodial, rx.is_move, rx.is_transient, rx.user_group
	    from t_req_request r
            join t_req_xfer rx on rx.request = r.id
            join ( select rds.request, rds.dataset_id dataset, NULL block
                     from t_req_dataset rds
                    where rds.dataset_id is not null
                    union
                   select rb.request, NULL dataset, rb.block_id block
                     from t_req_block rb
                    where rb.block_id is not null
                 ) rdata on rdata.request = r.id 
           where r.id = :request
         ) r
         on (r.destination = s.destination
             and (r.dataset = s.dataset or r.block = s.block))
         when matched then
           update set s.request = r.id,
                      s.is_move = r.is_move,
                      s.priority = r.priority,
                      s.is_transient = r.is_transient,
	              s.user_group = r.user_group
         when not matched then
           insert (request, dataset, block, destination,
		   priority, is_move, is_transient, is_custodial, user_group, time_create)
           values (r.id, r.dataset, r.block, r.destination,
		   r.priority, r.is_move, r.is_transient, r.is_custodial, r.user_group, :time_create) ],
			     ':request' => $rid, ':destination' => $node_id, ':time_create' => $time);

    return 1;
}

=pod

=item deleteSubscriptionsForRequest($self, $request, $node, $time)

Delete all subscriptions that match the request data for $request at $node.

=cut

sub deleteSubscriptionsForRequest
{
    my ($self, $rid, $node_id, $time) = @_;

    my ($sth, $rv) = &dbexec($$self{DBH},
    qq[ delete from t_dps_subscription s
         where s.destination = :destination
           and exists
               (select 1
 	          from t_req_request r
                  join ( select rds.request, rds.dataset_id dataset, b.id block
                           from t_req_dataset rds
                           left join t_dps_block b on b.dataset = rds.dataset_id
                           where rds.dataset_id is not null
                           union
                           select rb.request, b.dataset, b.id block
                             from t_req_block rb
                             join t_dps_block b on b.id = rb.block_id 
                            where rb.block_id is not null
                        ) rdata on rdata.request = r.id
                  where r.id = :request 
                    and (rdata.dataset = s.dataset or rdata.block = s.block)
               ) ],
	  ':request' => $rid, ':destination' => $node_id);

    return 1;
}

=pod

=item addDeletionsForRequest($self, $request, $node, $time)

Mark all blocks in the $request at $node for deletion.

=cut

sub addDeletionsForRequest
{
    my ($self, $rid, $node_id, $time) = @_;

    my ($sth, $rv) = &dbexec($$self{DBH}, 
     qq[ merge into t_dps_block_delete bd
         using
         (select r.id, rdata.dataset, rdata.block, :node node 
	    from t_req_request r
            join ( select rds.request, b.dataset, b.id block
                     from t_req_dataset rds
                     join t_dps_block b on b.dataset = rds.dataset_id
                    where rds.dataset_id is not null
                    union
                   select rb.request, b.dataset, b.id block
                     from t_req_block rb
                     join t_dps_block b on b.id = rb.block_id
                    where rb.block_id is not null 
                 ) rdata on rdata.request = r.id
           where r.id = :request
         ) r
         on (r.node = bd.node
             and r.dataset = bd.dataset
             and r.block = bd.block)
         when matched then
           update set request = r.id,
                      time_request = :time_request,
                      time_complete = NULL
            where time_complete is not null
         when not matched then
           insert (request, block, dataset, node, time_request)
           values (r.id, r.block, r.dataset, r.node, :time_request) ],
	  ':request' => $rid, ':node' => $node_id, ':time_request' => $time);

    return 1;
}

=pod

=item updateMoveSubscriptionsForRequest($self, $request, $node, $time)

Update the source subscriptions of a move.

NOTE: This query's "exists" clause contains a statement which checks
every possible block in the request for a match in the subscriptions
table of the given node this is probably quite expensive for large
requests...

=cut

sub updateMoveSubscriptionsForRequest
{
    my ($self, $rid, $node_id, $time) = @_;
    
    my ($sth, $rv) = &dbexec($$self{DBH},
    qq[ update t_dps_subscription s
           set s.time_clear = :time_clear
         where s.destination = :destination
           and exists
               (select 1
 	          from t_req_request r
                  join ( select rds.request, b.dataset, b.id block
                           from t_req_dataset rds
                           join t_dps_block b on b.dataset = rds.dataset_id
                           where rds.dataset_id is not null
                           union
                           select rb.request, b.dataset, b.id block
                             from t_req_block rb
                             join t_dps_block b on b.id = rb.block_id 
                            where rb.block_id is not null
                        ) rdata on rdata.request = r.id
                  where r.id = :request 
                    and (rdata.dataset = s.dataset or rdata.block = s.block)
               ) ],
	  ':request' => $rid, ':destination' => $node_id, ':time_clear' => $time);

    return 1;
}

=pod

=item setRequestDecision($self, $request, $node, $decision, $client, $time, $comment)

Sets the decision (y or n) of $node (made by $client) for $request.

=cut

sub setRequestDecision
{
    my ($self, $rid, $node_id, $decision, $client_id, $time, $comments_id) = @_;

    my ($sth, $rv) = &dbexec($$self{DBH}, qq{ 
	insert into t_req_decision (request, node, decision, decided_by, time_decided, comments)
	    values (:rid, :node, :decision, :decided_by, :time_decided, :comments) },
	    ':rid' => $rid, ':node' => $node_id, ':decision' => $decision, ':decided_by' => $client_id,
	    ':time_decided' => $time, ':comments' => $comments_id);
    
    return $rv ? 1 : 0;
}

=pod

=item unsetRequestDecision($self, $request, $node)

Clears the decision of $node for $request.

=cut

sub unsetRequestDecision
{
    my ($self, $rid, $node_id) = @_;

    my ($sth, $rv) = &dbexec($$self{DBH}, qq{ 
	delete from t_req_decision where request = :rid and node = :node },
	':rid' => $rid, ':node' => $node_id);
    
    return $rv ? 1 : 0;
}

=pod

=back

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,

=cut

1;
