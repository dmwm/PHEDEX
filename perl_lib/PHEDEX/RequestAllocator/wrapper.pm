package PHEDEX::RequestAllocator::wrapper;
1;

package PHEDEX::RequestAllocator::Core;

=head1 NAME

PHEDEX::RequestAllocator::Core - Specialized logic for dealing with requests

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 METHODS

=over

=cut


use warnings;
use strict;

use base 'PHEDEX::RequestAllocator::SQL';

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

=item expandRequest($self, $dbs, $data, %opts)

Expands a request (user field of data items) into arrays of IDs.

If the option EXPAND_DATASETS is true, datasets returned as a list of blocks.

=cut

sub expandDataClob
{
    my ($self, $dbs, $data, %opts) = @_;
    
    my %data = &parseUserClob($data);
    my @dataset_patterns;
    my @block_patterns;
    my @bad_patterns;
    while (my ($item, $level) = each %data) {
	if (! $level ) { # undefined level means bad data format
	    push @bad_patterns, $item;
	    next;
	}
	my $pat = $item;
	$pat =~ s/\*+/%/g; # replace '*' with sql '%'
	push @dataset_patterns, $pat if $level eq 'DATASET';
	push @block_patterns, $pat if $level eq 'BLOCK';
    }

    my (@datasets, @blocks);
    if (@dataset_patterns && $opts{EXPAND_DATASETS} ) {
	my $b = &getBlockIDsFromDatasetWildcard($self, $dbs, @dataset_patterns);
	push @blocks, @$b;
    } elsif (@dataset_patterns) {
	my $ds = &getDatasetIDsFromDatasetWildcard($self, $dbs, @dataset_patterns);
	push @datasets, @$ds;
    }

    if (@block_patterns) {
	my $b = &getBlockIDsFromBlockWildcard($self, $dbs, @block_patterns);
	push @blocks, @$b;
    }
    
    return (\@datasets, \@blocks, \@bad_patterns);

}

=pod

=item parseUserClob(@userdata)

Takes an array of user data clobs and parses out single dataset and block globs
Returns a hash of key:  glob pattern value: item type (DATASET or BLOCK)

=cut

sub parseUserClob
{
    my (@userdata) = @_;
    my %parsed;
    foreach my $string (@userdata) {
	$string =~ s/^\s+//;  $string =~ s/\s+$//;
	my @data = split(/\s+/, $string);
	foreach my $item (@data) {
	    if ($item =~ m<^/[^/]+/[^/]+(/[^/]+|\#[^\#]+)$>) {
		$parsed{$item} = ($1 =~ /\#/ ? 'BLOCK' : 'DATASET');
	    } else {
		$parsed{$item} = undef;
	    }
	}
    }
    return %parsed;
}

# distributes datasets, blocks among nodes
sub distributeData
{
    my ($self, %h) = @_;
    unless ($h{NODES} && ($h{DATASETS} || $h{BLOCKS})) {
	die "distributeData requires NODES and (DATASETS or BLOCKS)";
    }

    my %items;
    $items{DATASET} = $h{DATASETS} if $h{DATASETS} && ref $h{DATASETS} eq 'ARRAY';
    $items{BLOCK} = $h{BLOCKS} if $h{BLOCKS} && ref $h{BLOCKS} eq 'ARRAY';

    my $dist = [];
    # Distribute to all nodes
    foreach my $node (@{ $h{NODES} }) {
	foreach my $type ( keys %items ) {
	    foreach my $id ( @{ $items{$type} } ) {
		push @$dist, [$type, $node, $id];
	    }
	}
    }
    
    return $dist;
}


sub validateRequest
{
    my ($self, $data, $nodes, %h) = @_;

    # check parameters
    foreach my $req (qw(CLIENT_ID TYPE)) {
	die "required parameter $req is not defined\n"
	    unless exists $h{$req} && defined $h{$req};
    }

    my @typereq;
    if ( $h{TYPE} eq 'xfer' ) { 
	@typereq = qw( PRIORITY IS_MOVE IS_STATIC IS_TRANSIENT IS_DISTRIBUTED IS_CUSTODIAL); 
    } elsif ( $h{TYPE} eq 'delete' ) {
	@typereq = qw( RM_SUBSCRIPTIONS );
    } else {
	die "type '$h{TYPE}' is not valid\n";
    }
    foreach my $req (@typereq) {
	die "required $h{TYPE} parameter $req is not defined\n"
	    unless exists $h{$req} && defined $h{$req};
    }

    my $type = $h{TYPE};
    my $client = $h{CLIENT_ID};
    
    # Part I:  validate data
    my $dataformat = $data->{FORMAT};
    my $expand_datasets = $type eq 'xfer' && $h{IS_STATIC} eq 'y' ? 1 : 0;

    my ($ds_ids, $b_ids);

    if ($dataformat eq 'tree') { # heirachical representation (user XML)
	# resolve the DBS
	my $dbs = $data->{NAME};
	my $db_dbs = &getDbsFromName($self, $dbs);
	if (! $db_dbs->{ID} ) {
	    die "dbs '$dbs' does not exist\n";
	}
	$h{DBS_NAME} = $dbs;
	$h{DBS_ID} = $db_dbs->{ID};

	# find datasets/and blocks
	my (@datasets, @blocks);
	foreach my $ds (values %{$data->{DATASETS}}) {
	    # peek at the number of blocks
	    my $n_blocks = scalar keys %{$ds->{BLOCKS}};
	    my @rv;
	    if ($h{LEVEL} eq 'DATASET' || $n_blocks == 0) { # make dataset level request
		push @datasets, $ds->{NAME};
	    } else { # make block level request
		foreach my $b (values %{$ds->{BLOCKS}}) {
		    push @blocks, $b->{NAME};
		} # /block
	    } # /block-level case
	} # /dataset
	    
	if (!@datasets && !@blocks) {
	    die "request contains no data\n";
	}

	# ensure unique data
	# TODO: improve efficiency by rewriting expandDataClob to take
	#       already parsed data patterns instead of a clob?
	my (%uniq_ds, %uniq_b);
	my (@null);
	foreach my $item (@datasets, @blocks) {
	    ($ds_ids, $b_ids) = &expandDataClob($self, $db_dbs->{ID}, $item,
						EXPAND_DATASETS => $expand_datasets );
	    if ( @$ds_ids || @$b_ids ) {
		# item exists in TMDB, remember the IDs
		$uniq_ds{$_} = 1 foreach @$ds_ids;
		$uniq_b{$_} = 1 foreach @$b_ids;
	    } else {
		# item does not exist, remember that it does not
		push @null, $item;
	    }
	}
	    
	$ds_ids = [ keys %uniq_ds ];
	$b_ids =  [ keys %uniq_b  ];

	# make a data clob for storage
	$h{DATA} = join("\n", @datasets, @blocks);
    } elsif ($dataformat eq 'flat') { # flat data representation (user text)
	# resolve the dbs
	my $dbs = $data->{DBS};
	my $db_dbs = &getDbsFromName($self, $dbs);
	if (! $db_dbs->{ID} ) {
	    die "dbs '$dbs' does not exist\n";
	}
	$h{DBS_NAME} = $dbs;
	$h{DBS_ID} = $db_dbs->{ID};
	
	# expand the data text
	($ds_ids, $b_ids) = &expandDataClob($self, $db_dbs->{ID}, $data->{DATA},
					    EXPAND_DATASETS => $expand_datasets );

	# make a data clob for storage
	$h{DATA} = $data->{DATA};
    } else {
	die "request has an unknown data structure\n";
    }

    # Part II:  validate nodes
    # Request policy details here:
    #  * Moves may only be done to a T1 MSS node
    #  * Moves can not be done when data is subscribed at a T1
    #  * Custodiality only applies to a T[01] MSS node
    my @node_pairs;
    my %nodemap = reverse %{ &getNodeMap($self) };
    foreach my $node (@$nodes) {
	die "node '$node' does not exist\n" unless exists $nodemap{$node};
    }

    if ($type eq 'delete') {
	# deletion requests do not define endpoints
	@node_pairs = map { [ undef, $nodemap{$_} ] } @$nodes;
    } elsif ($type eq 'xfer') { # user specifies destinations
	@node_pairs = map { [ 'd', $nodemap{$_} ] } @$nodes;
	# already subscribed nodes for the data specify sources for move requests
	if ($h{IS_MOVE} eq 'y') {
	    if (grep $_ !~ /^T1_.*_MSS$/, @$nodes) {
		die "cannot request move:  moves to non-T1 destinations are not allowed\n";
	    }

	    my %sources;
	    if (@$ds_ids) {
		my $sql = qq{ select distinct n.name
			        from t_adm_node n
                                join t_dps_subscription s on s.destination = n.id
                                join t_dps_block sb on sb.dataset = s.dataset or sb.id = s.block
                               where sb.dataset = :dataset
			   };
		foreach my $ds (@$ds_ids) {
		    my @other_subs = @{ &select_single($self, $sql, ':dataset' => $ds) };		
		    $sources{$_} = 1 foreach @other_subs;
		}
	    } elsif (@$b_ids) {
		my $sql = qq{ select distinct n.name
			        from t_adm_node n
                                join t_dps_subscription s on s.destination = n.id
                                join t_dps_block sb on sb.dataset = s.dataset or sb.id = s.block
                               where sb.id = :block
			   };
		foreach my $b (@$b_ids) {
		    my @other_subs = @{ &select_single($self, $sql, ':block' => $b) };		
		    $sources{$_} = 1 foreach @other_subs;
		}
	    }

	    die "cannot request move:  moves of data is subscribed to T0 or T1 are not allowed\n"
		if grep /^(T1|T0)/, keys %sources;
	    push @node_pairs, map { [ 's', $nodemap{$_} ] } keys %sources;
	}
	
	if ($h{IS_CUSTODIAL} eq 'y') {
	    if (grep $_ !~ /^T[01]_.*_MSS$/, @$nodes) {
		die "cannot request custodial transfer to non T0, T1 MSS nodes\n";
	    }
	}
    }

    return ($ds_ids, $b_ids, \@node_pairs, %h);
}

=pod

=item createRequest($self, $data, $nodes, %args)

Creates a new request, returns the newly created request id.

TODO:  document format for $data and $nodes hash.

=cut

sub createRequest
{
    my ($self, $ds_ids, $b_ids, $node_pairs, %h) = @_;

    my $now = $h{NOW} || &mytimeofday();
    my $type = $h{TYPE};

    # Write the request
    my $rid;
    &execute_sql($self,
		qq[insert into t_req_request (id, type, created_by, time_create)
		   values (seq_req_request.nextval, (select id from t_req_type where name = :type),
			   :client, :now )
		   returning id into :id ],
		':id' => \$rid, ':type' => $h{TYPE}, ':client' => $h{CLIENT_ID}, ':now' => $now);

    # Write the (resolved) dbs/datasets/blocks to the DB
    &execute_sql($self, 
		 qq[ insert into t_req_dbs (request, name, dbs_id)
		     values (:rid, :dbs_name, :dbs_id) ],
		 ':rid' => $rid, ':dbs_name' => $h{DBS_NAME}, ':dbs_id' => $h{DBS_ID});


    if ( @$ds_ids || @$b_ids ) {
	&addRequestData($self, $rid, DATASET => $_) foreach @$ds_ids;
	&addRequestData($self, $rid, BLOCK => $_) foreach @$b_ids;
    } else {
	die "request matched no data in TMDB\n";
    }

    # Write the nodes involved
    my $i_node = &dbprep($self->{DBH},
			 qq[ insert into t_req_node (request, node, point)
			     values (:rid, :node, :point) ]);
    foreach my $pair (@$node_pairs) {
	my ($endpoint, $node_id) = @$pair;
	&dbbindexec($i_node,
		    ':rid' => $rid,
		    ':node' => $node_id,
		    ':point' => $endpoint);
    }

    # Write the request type parameters
    if ($type eq 'xfer') {
	my $sql = qq{ insert into t_req_xfer
			  (request, priority, is_custodial, is_move, is_static,
			   is_transient, is_distributed, user_group, data)
			  values
			  (:request, :priority, :is_custodial, :is_move, :is_static,
			   :is_transient, :is_distributed, :user_group, :data) };
	my %binds;
	$binds{':request'} = $rid;
	$binds{lc ":$_"} = $h{$_} foreach qw(PRIORITY IS_CUSTODIAL IS_MOVE IS_STATIC
					     IS_TRANSIENT IS_DISTRIBUTED DATA);
	if (defined $h{USER_GROUP}) {
	    my %groupmap = reverse %{ &getGroupMap($self) };
	    my $group_id = $groupmap{ $h{USER_GROUP} };
	    $binds{':user_group'} = $group_id;
	} else { 
	    $binds{':user_group'} = undef; 
	}
	&execute_sql($self, $sql, %binds);
    } elsif ($type eq 'delete') {
	my $sql = qq{ insert into t_req_delete
			  (request, rm_subscriptions, data)
			  values
			  (:request, :rm_subscriptions, :data) };
	my %binds;
	$binds{':request'} = $rid;
	$binds{lc ":$_"} = $h{$_} foreach qw(RM_SUBSCRIPTIONS DATA);
	&execute_sql($self, $sql, %binds);
    }
    
    # Write the comment
    if ($h{COMMENTS}) {
	my $comments_id = &writeRequestComments($self, $rid, $h{CLIENT_ID}, $h{COMMENTS}, $now);
	&execute_sql($self, qq[ update t_req_request set comments = :comments_id where id = :rid ],
		    ':rid' => $rid, ':comments_id' => $comments_id);
    }

    return $rid;
}

=pod

=back

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,

=cut

1;
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

=item updateMoveSubscriptionsForRequest($self, $request, $time)

Update the source subscriptions of a move request.

=cut

sub updateMoveSubscriptionsForRequest
{
    my ($self, $rid, $time) = @_;

    my $q_src = &dbexec($$self{DBH}, qq{
  select distinct s.destination, s.dataset, s.block,
         decode(rdec.decision,
                'y', :now,
                'n', NULL,
                 9999999999) time_clear
    from t_req_request r
    join (
          select rds.request, b.dataset, b.id block
            from t_req_dataset rds
            join t_dps_block b on b.dataset = rds.dataset_id
           where rds.dataset_id is not null
           union
          select rb.request, b.dataset, b.id block
            from t_req_block rb
            join t_dps_block b on b.id = rb.block_id
           where rb.block_id is not null
         ) rdata 
      on rdata.request = r.id
    join t_req_node rn
      on rn.request = r.id
    join t_dps_subscription s
      on s.destination = rn.node
     and (s.dataset = rdata.dataset or s.block = rdata.block)
    left join t_req_decision rdec
      on rdec.request = rn.request and rdec.node = rn.node
   where r.id = :request and rn.point = 's'
}, ':request' => $rid, ':now' => $time);

    my $upd_ds = &dbprep($$self{DBH}, qq{
	update t_dps_subscription set time_clear = :time_clear
	    where destination = :destination and dataset = :dataset });

    my $upd_b = &dbprep($$self{DBH}, qq{
	update t_dps_subscription set time_clear = :time_clear
	    where destination = :destination and block = :block });

    my $src_subscriptions = $q_src->fetchall_arrayref({});
    my $updated = 0;
    foreach my $s ( @$src_subscriptions ) {
	my ($sth, $rv);
	if (!defined $s->{BLOCK}) {
	    ($sth, $rv) = &dbbindexec($upd_ds, 
				      ':time_clear' => $s->{TIME_CLEAR},
				      ':destination' => $s->{DESTINATION},
				      ':dataset' => $s->{DATASET});
	} else {
	    ($sth, $rv) = &dbbindexec($upd_b,
				      ':time_clear' => $s->{TIME_CLEAR},
				      ':destination' => $s->{DESTINATION},
				      ':block' => $s->{BLOCK});
	}
	$updated += $rv;
    }

    return $updated;
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
