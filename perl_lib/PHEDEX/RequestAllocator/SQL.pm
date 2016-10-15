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
	       rx.user_group, rx.is_custodial, rx.time_start
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

    $self->{DBH}->{LongReadLen} = 1_000_000;
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
				    IS_DISTRIBUTED IS_CUSTODIAL USER_GROUP TIME_START
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

    $self->{DBH}->{LongReadLen} = 1_000_000;
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
					       and rds.request = :id },
					':id' => $request );
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
    $type = 'FILE'    if $h{FILE};
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
                                                                                                             
=item createSubscriptionParam($self, %args)

Creates a new subscription parameter set. Returns the id of the new parameter set.
Required:
 REQUEST : request ID this is associated with
 USER_GROUP : the user group ID
 PRIORITY : priority
 IS_CUSTODIAL : the custodiality
 ORIGINAL : if this is the original parameter set for this request.
    If the original param set already exists, it will be returned instead of creating a new param set.
 TIME_CREATE : the parameter set creation time

=cut

sub createSubscriptionParam
{
    my ($self, %h) = @_;
 
    my @required = qw(REQUEST USER_GROUP PRIORITY IS_CUSTODIAL ORIGINAL TIME_CREATE);
    foreach (@required) {
	if (!exists $h{$_} || !defined $h{$_}) {
	    $self->Alert("cannot create subscription param:  $_ not defined");
            return undef;
	}
    }
    
    foreach ( qw(IS_CUSTODIAL ORIGINAL) ) {
        next unless  $h{$_} =~ /^[0-9]$/;
        $h{$_} = ( $h{$_} ? 'y' : 'n' );
    }

#   If this is the original parameter set for the request, check that it doesn't exist already
    if ($h{ORIGINAL} eq 'y') {
	my $param = select_hash ($self->{DBH},                                     
				   qq{select id, user_group, priority, is_custodial from t_dps_subs_param pm     
                                      where pm.original = :original                                   
                                      and pm.request = :request},  'ID',               
				 ':original' => 'y', ':request'  => $h{REQUEST});
	
        # FIXME: This assumes that there is only one original parameter set per request. How to ensure this?
	for my $rid ( keys %$param ) {
	    my $rparam = $param->{$rid};
	    foreach ( keys %$rparam ) {
		if ($rparam->{$_} ne $h{$_}){
		    $self->Alert("cannot create param set: original
already exists with id " . $rid . " and different values: " . $_. " existing=" . $rparam->{$_} . " requested=" . $h{$_});
		    return undef;
		}
	    }
	    $self->Dbgmsg("Original subscription parameter set already exists with id " . $rid) if $self->{DEBUG};
	    return $rid;
	}
    }
    
    my $sql=qq{ insert into t_dps_subs_param (id, request, priority, is_custodial, user_group, original, time_create)                                    
                    values (seq_dps_subs_param.nextval, :request, :priority, :is_custodial, :user_group, :original, :time_create)
                    returning id into :param_id};
    	    
    my $param_id;
    my %p = map { ':' . lc $_ => $h{$_} } @required;                                                                      
    $p{':param_id'}=\$param_id;
   
    my ($sth, $n);
    eval { ($sth, $n) = execute_sql($self, $sql, %p); };

    return $param_id;
    
}

=pod

=item createSubscription($self, %args)

Creates a new subscription for a dataset or block.

Required:
 DATASET or BLOCK : the name or ID of a dataset or block
 PARAM : parameter set ID this is associated with
 DESTINATION : the destination node ID
 IS_MOVE : if this is a move subscription
 TIME_START: the starting time for the subscription (can be NULL)
  Only blocks injected after TIME_START will be subscribed
 TIME_CREATE : the creation time
Optional only one of:
 IGNORE_DUPLICATES : if true, ORA-00001 errors from trying to create a duplicate subscription will
  not result in an exception
 SKIP_DUPLICATES : if true, the function will not try to insert the subscription if it already exists,
  or if it will be created by the BlockAllocator agent on the next cycle

=cut

sub createSubscription
{
    my ($self, %h) = @_;

    my $type;
    $type = 'DATASET' if defined $h{DATASET};
    $type = 'BLOCK'   if defined $h{BLOCK};
    if (!defined $type || (defined $h{DATASET} && defined $h{BLOCK})) {
	$self->Alert("cannot create subscription:  DATASET or BLOCK must be defined");
	return undef;
    }

    my @required = qw(PARAM DESTINATION IS_MOVE TIME_CREATE);
    foreach (@required) {
	if (!exists $h{$_} || !defined $h{$_}) {
	    $self->Alert("cannot create subscription:  $_ not defined");
	    return undef;
	}
    }

#   Special case for TIME_START, which must exist but may be NULL
    if (!exists $h{TIME_START}) {
	$self->Alert("cannot create subscription: TIME_START not defined");
	return undef;
    }

    if ($h{IGNORE_DUPLICATES} && $h{SKIP_DUPLICATES}) {
	$self->Alert("cannot create subscription: only one of IGNORE_DUPLICATES and SKIP_DUPLICATES allowed");
	return undef;
    }
    
    if ($h{IS_MOVE} =~ /^[0-9]$/) {
	$h{IS_MOVE} = ( $h{IS_MOVE} ? 'y' : 'n' );
    }
    
    my $sql = qq{insert into t_dps_subs_} . lc $type ;
    my %p = map { ':' . lc $_ => $h{$_} } @required;

    if ($type eq 'DATASET') {
	$sql .= qq{ (destination, dataset, param,
		     is_move, time_create, time_fill_after) 
		    };
	%p = (%p, (map { ':' . lc $_ => $h{$_} } qw(DATASET TIME_START)));
	
	if ($h{$type} !~ /^[0-9]+$/) { # if not an ID, then lookup IDs from the name
	    $sql .= qq{ select :destination, ds.id, :param,
			:is_move, :time_create, :time_start                                     
			from t_dps_dataset ds
		    };
	    if ($h{SKIP_DUPLICATES}) {
		$sql .= qq{ left join t_dps_subs_dataset dsold
				on dsold.destination=:destination
				and dsold.dataset=ds.id
			    };
	    }
	    $sql .= qq{ where ds.name = :dataset };
	    if ($h{SKIP_DUPLICATES}) {
		$sql .= qq{ and dsold.dataset is null }
	    }
	} else { # else we write exactly what we have
	    $sql .= qq{ select :destination, :dataset, :param, :is_move, :time_create, :time_start from dual
			};
	    if ($h{SKIP_DUPLICATES}) {
		$sql .= qq{ left join t_dps_subs_dataset dsold
                                on dsold.destination=:destination
                                and dsold.dataset=:dataset
			    where dsold.dataset is null
			};
	    }
	}
    } elsif ($type eq 'BLOCK') {                                                                                                                         
	$sql .= qq{ (destination, dataset, block, param,
		     is_move, time_create)
		    };

	%p = (%p, map { ':' . lc $_ => $h{$_} } qw(BLOCK TIME_START));                                                                                       

	if ($h{$type} !~ /^[0-9]+$/) { # if not an ID, then lookup IDs from the name
	    $sql .= qq{ select distinct :destination, b.dataset, b.id, :param, :is_move, :time_create 
			    from t_dps_block b
			};
	    if ($h{SKIP_DUPLICATES}) { 
		$sql .= qq{ left join t_dps_subs_dataset dsold
				on dsold.destination=:destination
				and dsold.dataset=b.dataset
				and b.time_create>nvl(dsold.time_fill_after,-1)
			    left join t_dps_subs_block bsold 
			        on bsold.destination=:destination
				and bsold.block=b.id
			    };
	    }
	    $sql .= qq{ where b.name = :block and b.time_create > nvl(:time_start,-1) };
	    if ($h{SKIP_DUPLICATES}) {
		$sql .= qq{ and dsold.dataset is null and bsold.block is null };
	    }
	    
	} else { # else we only lookup dataset ID from block ID
	    $sql .= qq{ select distinct :destination, b.dataset, :block, :param, :is_move, :time_create
                            from t_dps_block b
			};
	    if ($h{SKIP_DUPLICATES}) {
                $sql .= qq{ left join t_dps_subs_dataset dsold
				on dsold.destination=:destination
				and dsold.dataset=b.dataset
				and b.time_create>nvl(dsold.time_fill_after,-1)
			    left join t_dps_subs_block bsold
			        on bsold.destination=:destination
				and bsold.block=:block
			    }; 
		}
	    $sql .= qq { where b.id = :block and b.time_create > nvl(:time_start,-1) };
	    if ($h{SKIP_DUPLICATES}) {
		$sql .= qq{ and dsold.dataset is null and bsold.block is null };
	    }
	}
    }
    
    my ($sth, $n);
    eval { ($sth, $n) = execute_sql( $self, $sql, %p ); };
    die $@ if $@ && !($h{IGNORE_DUPLICATES} && $@ =~ /ORA-00001/);

    return $n;
}

=pod

=item updateSubscription($self, %args)

Updates subscription parameters for an existing subscription for a dataset or block.

Required:
 DATASET or BLOCK : the name or ID of a dataset or block
 DESTINATION : the destination node ID                                                              
 PARAM or TIME_SUSPEND_UNTIL:
    PARAM: the new parameter set ID to associate to this subscription
    TIME_SUSPEND_UNTIL : the new suspension time for the subscription, may be null for unsuspensions

=cut

sub updateSubscription
{
    my ($self, %h) = @_;

    my $type;
    $type = 'DATASET' if defined $h{DATASET};
    $type = 'BLOCK'   if defined $h{BLOCK};
    if (!defined $type || (defined $h{DATASET} && defined $h{BLOCK})) {
	$self->Alert("cannot update subscription:  DATASET or BLOCK must be defined");
	return undef;
    }

    my $updatevar;
    $updatevar = 'PARAM' if defined $h{PARAM}; 
    $updatevar = 'TIME_SUSPEND_UNTIL' if exists $h{TIME_SUSPEND_UNTIL};
    if (!defined $updatevar || (defined $h{PARAM} && exists $h{TIME_SUSPEND_UNTIL})) { 
        $self->Alert("cannot update subscription:  PARAM or TIME_SUSPEND_UNTIL must be defined"); 
        return undef; 
    }

    my @required = qw(DESTINATION);
    foreach (@required) {
	if (!exists $h{$_} || !defined $h{$_}) {
	    $self->Alert("cannot update subscription:  $_ not defined");
	    return undef;
	}
    }

    my $sql = qq{update t_dps_subs_} . lc $type . qq{ set } . lc $updatevar . qq {= :} . lc $updatevar;
    my %p = map { ':' . lc $_ => $h{$_} } @required, ($type, $updatevar);

    if ($h{$type} !~ /^[0-9]+$/) { # if not an ID, then lookup IDs from the name
	$sql .= qq{ where destination = :destination
		     and } . lc $type . qq{ = (select id from t_dps_} . lc $type . qq{ where name = :} . lc $type .qq{)};
	} else { # else we write exactly what we have
	    $sql .= qq{ where destination = :destination and } . lc $type . qq{= :} . lc $type;       
	}
    
    my ($sth, $n);
    eval { ($sth, $n) = execute_sql( $self, $sql, %p ); };
        
    return $n;
}

=pod

=item deleteSubscription($self, %args)

Remove an existing subscription for a dataset. This operation is not allowed for a block;
 block unsubscription is only allowed through deletion requests.

Required:
 DATASET: the name or ID of a dataset
 DESTINATION : the destination node ID

=cut

sub deleteSubscription
{
    my ($self, %h) = @_;

    my @required = qw(DATASET DESTINATION);
    foreach (@required) {
	if (!exists $h{$_} || !defined $h{$_}) {
	    $self->Alert("cannot delete subscription: $_ not defined");
	    return undef;
	}
    }

    my $sql = qq {delete from t_dps_subs_dataset};
    my %p = map { ':' . lc $_ => $h{$_} } @required;
    
    if ($h{DATASET} !~ /^[0-9]+$/) { # if not an ID, then lookup IDs from the name
	$sql .= qq{ where destination = :destination
		     and dataset = (select id from t_dps_dataset where name = :dataset)};
	} else { # else we write exactly what we have
	    $sql .= qq{ where destination = :destination and dataset = :dataset};
	}
    
    my ($sth, $n);
    eval { ($sth, $n) = execute_sql( $self, $sql, %p ); };
    
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

=item addSubscriptionForParamSet($self, $param, $node, $time)

Subscribe request data to $node for $param.  This DML ignores
duplicates but updates the parameters if there are duplicates.

=cut

sub addSubscriptionsForParamSet
{
    my ($self, $paramid, $node_id, $time) = @_;

    my ($sth, $rv) = &dbexec($$self{DBH},
     qq[ merge into t_dps_subs_block sb                                                                                                                     
         using
         (select :destination destination, bk.dataset, bk.id block,                                                                                 
                 :param param, rx.is_move, pm.is_custodial
	    from t_req_request r 
            join t_req_xfer rx on rx.request = r.id  
            join t_req_block rb on rb.request = r.id
	    join t_dps_block bk on bk.id=rb.block_id
            join t_dps_subs_param pm on pm.request = r.id   
            where pm.id = :param and bk.time_create > nvl(rx.time_start,-1)   
         ) rd   
         on (rd.destination = sb.destination   
             and (rd.block = sb.block))                                                                                               
         when matched then
           update set sb.param = rd.param, sb.is_move = rd.is_move
	    where rd.is_custodial=(select is_custodial from t_dps_subs_param where id=sb.param)
	          and (sb.is_move = 'n' or sb.is_move = rd.is_move)
         when not matched then
	   insert (destination, dataset, block, param, is_move, time_create)
           values (rd.destination, rd.dataset, rd.block, rd.param,   
                   rd.is_move, :time_create) ],                                                     
                             ':param' => $paramid, ':destination' => $node_id, ':time_create' => $time);

    my ($sthb, $rvb) = &dbexec($$self{DBH},   
     qq[ merge into t_dps_subs_dataset sd                
         using     
         (select :destination destination, rds.dataset_id dataset,
	         :param param, rx.time_start time_fill_after, rx.is_move, pm.is_custodial 
            from t_req_request r    
            join t_req_xfer rx on rx.request = r.id   
            join t_req_dataset rds on rds.request = r.id  
	    join t_dps_subs_param pm on pm.request = r.id   
            where pm.id = :param 
         ) rd  
         on (rd.destination = sd.destination  
             and (rd.dataset = sd.dataset)) 
         when matched then  
           update set sd.param = rd.param , sd.time_fill_after = rd.time_fill_after,
	              sd.is_move = rd.is_move
	    where rd.is_custodial=(select is_custodial from t_dps_subs_param where id=sd.param)
	          and (sd.is_move = 'n' or sd.is_move = rd.is_move)
         when not matched then    
           insert (destination, dataset, param, time_fill_after, is_move, time_create) 
           values (rd.destination, rd.dataset, rd.param,
                   rd.time_fill_after, rd.is_move, :time_create) ],   
                             ':param' => $paramid, ':destination' => $node_id, ':time_create' => $time);

    return 1;
}

=pod

=item deleteSubscriptionsForRequest($self, $request, $node, $time)

Delete all subscriptions that match the request data for $request at $node.

=cut

sub deleteSubscriptionsForRequest
{
    my ($self, $rid, $node_id, $time) = @_;

#For dataset-level deletion requests only, remove dataset-level subscriptions

    my ($dsth, $drv) = &dbexec($$self{DBH},   
    qq[ delete from t_dps_subs_dataset sd     
         where sd.destination = :destination
          and sd.dataset in      
           (select rds.dataset_id  
	      from t_req_dataset rds
	      join t_req_request r on rds.request=r.id
	      where r.id = :request 
           ) ],  
         ':request' => $rid, ':destination' => $node_id);

#Remove block-level subscriptions, both for dataset-level and for block-level deletion requests
    
    my ($sth, $rv) = &dbexec($$self{DBH},
    qq[ delete from t_dps_subs_block sb
         where sb.destination = :destination 
           and sb.block in
	    (select rb.block_id
	       from t_req_block rb
	       join t_req_request r on r.id=rb.request
	       where r.id = :request
	     union
	     select b.id from t_dps_block b
	       join t_req_dataset rds
	       on rds.dataset_id=b.dataset
	       join t_req_request r on r.id=rds.request
	       where r.id = :request
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

    # Look for locally connected Buffers.  We need to add deletions
    # for MSS nodes where data may be on the Buffer but not yet on the
    # MSS node
    my $local_buffers = &select_single($$self{DBH},
     qq[ select l.to_node from t_adm_link l
           join t_adm_node fn on fn.id = l.from_node
           join t_adm_node tn on tn.id = l.to_node
	  where l.from_node = :node
            and l.is_local = 'y'
            and tn.kind = 'Buffer' ],
	':node' => $node_id);

    foreach my $lookup_node ($node_id, @$local_buffers) {
	my ($sth, $rv) = &dbexec($$self{DBH},
          qq[ merge into t_dps_block_delete bd
              using
              (select r.id, rdata.dataset, rdata.block, :del_node node
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
                 join t_dps_block_replica br on br.block = rdata.block
                where r.id = :request
                  and br.node = :lookup_node
                  and br.node_files + br.xfer_files != 0
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
     ':request' => $rid, 
     ':del_node' => $node_id, 
     ':lookup_node' => $lookup_node,
     ':time_request' => $time);
    }
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
