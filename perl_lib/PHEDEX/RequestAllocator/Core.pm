package PHEDEX::RequestAllocator::Core;

=head1 NAME

PHEDEX::RequestAllocator::Core - Specialized logic for dealing with requests

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 METHODS

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

=over

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
    my (%parsed,$userdata,@userdata);
    foreach $userdata ( shift ) {
      if ( ref($userdata) eq 'ARRAY' ) {
        foreach ( @{$userdata} ) { push @userdata,$_; }
      } else {
        push @userdata, $userdata;
      }
    }
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

=pod

=item validateGroup($self, $groupname)

Looks for group with name $groupname in group table.
Returns group ID if group exists and is valid.
Returns undef if group doesn't exist or is deprecated.

=cut

sub validateGroup
{
    my ($self, $groupname) = @_;
    return unless $groupname;
    return if $groupname =~ '^deprecated-.*';
    my %groupmap = reverse %{ &getGroupMap($self) };
    my $group_id = $groupmap{ $groupname };
    return $group_id;
}

=pod

=item validateRequest($self, $data, $nodes, %args)

Checks request parameters according to the request type and data format. 
Returns validated parameters that can be passed directly to createRequest. 
TODO: document data formats. 

=over 

=item *

C<$data>  is a  hash reference, where $data->{FORMAT} must match one of the supported 
formats:  'lfns', 'tree', 'flat', or 'existingrequestdata' as returned by 
getExistingRequestData, e.g. in UpdateRequest API, and $data->{DBS} is required but not used 
(a legacy feature?)
    
=item *

C<$nodes>  is an  array reference with a list of node names

=item *

C<%args> is a hash used to pass other required parameters: TYPE, CLIENT_ID.

=back

=cut

sub validateRequest
{
    my ($self, $data, $nodes, %h) = @_;

    # check parameters
    foreach my $req (qw(CLIENT_ID TYPE INSTANCE)) {
	die "required parameter $req is not defined\n"
	    unless exists $h{$req} && defined $h{$req};
    }

    my @typereq;
    if ( $h{TYPE} eq 'xfer' ) { 
	@typereq = qw( PRIORITY USER_GROUP IS_MOVE IS_STATIC IS_TRANSIENT IS_DISTRIBUTED IS_CUSTODIAL); 
    } elsif ( $h{TYPE} eq 'delete' ) {
	@typereq = qw( RM_SUBSCRIPTIONS );
    } elsif ( $h{TYPE} eq 'invalidate' ) {
	# If needed, pass additional parameters here:
	@typereq = ();
	#@typereq = qw( INV_REPLICAS );
    } else {
	die "type '$h{TYPE}' is not valid\n";
    }
    foreach my $req (@typereq) {
	die "required $h{TYPE} parameter $req is not defined\n"
	    unless exists $h{$req} && defined $h{$req};
    }

    my $type = $h{TYPE};
    my $client = $h{CLIENT_ID};
    
    if ($type eq 'xfer' && $h{TIME_START} && $h{IS_MOVE} eq 'y') {
	die "cannot create request: Time-based move requests are not allowed\n";
    }
    
    if ($type eq 'delete' && $h{TIME_START}) {
	die "cannot create request: Time-based deletion requests are not allowed\n";
    }

    # By analogy with the previous two checks, enable if needed
    # (do we ever want a delayed invalidation/re-transfer?): 
    #if ($type eq 'invalidate' && $h{TIME_START}) {
	#die "cannot create request: Time-based invalidation requests are not allowed\n";
    #}

    # Part 0: validate groups
    if ($type eq 'xfer') {
	die "cannot create request: USER_GROUP $h{USER_GROUP} not found\n"
	    unless &validateGroup( $self, $h{USER_GROUP} );
    }

    # Part I:  validate data
    my $dataformat = $data->{FORMAT};
    my $expand_datasets = $type eq 'xfer' && $h{IS_STATIC} eq 'y' ? 1 : 0;

    my ($ds_ids, $b_ids);

    if ($dataformat eq 'lfns') { # user supplied list of LFNs  
	print "NRDEVEL  TODO: implement processing of the LFNs list\n";
    } elsif ($dataformat eq 'tree') { # heirachical representation (user XML)
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
    } elsif ($dataformat eq 'existingrequestdata') { # from getExistingRequestData
	$ds_ids = $data->{DATASET_IDS};
	$b_ids  = $data->{BLOCK_IDS};
	$h{DBS_NAME} = $data->{DBS};
	$h{DBS_ID}   = $data->{DBS_ID};
	$h{DATA}     = $data->{DATA};
    } else {
      die "request has an unknown data structure\n";
    }
    
    # Part II:  validate nodes
    # Request policy details here:
    #  * Transfers and deletions on Buffer nodes are not allowed in prod instance
    #  * Custodiality only applies to a T[01] MSS node
    #  * Custodiality changes through a request are not allowed
    #  * Changing a move flag to 'n' through a request is not allowed
    #  * Moves may only be done to a T1 MSS node
    #  * Moves can be done when data is already subscribed to T[01] nodes. They will not trigger deletions at T[01] nodes
    
    my @node_pairs;
    my %nodemap = reverse %{ &getNodeMap($self) };
    foreach my $node (@$nodes) {
	die "node '$node' does not exist\n" unless exists $nodemap{$node};
    }

    if ( $h{INSTANCE} eq 'prod' && (grep /^T[01]_.*_(Buffer|Export)$/, @$nodes)) {
	die "cannot request $type to T0 or T1 Buffer node in $h{INSTANCE} instance\n";
    }

    if ($type eq 'delete') {
	# deletion requests do not define endpoints
	@node_pairs = map { [ undef, $nodemap{$_} ] } @$nodes;
    } elsif ($type eq 'xfer') { # user specifies destinations
	@node_pairs = map { [ 'd', $nodemap{$_} ] } @$nodes;

	if ($h{IS_CUSTODIAL} eq 'y') {
            if (grep $_ !~ /^T[01]_.*_MSS$/, @$nodes) {
                die "cannot request custodial transfer to non T0, T1 MSS nodes\n";
            }
        }
	
	# Check existing subscriptions to destination node for custodiality/move flag changes
	# Check existing subscriptions to other nodes as sources for move requests
	
	my %sources;
	if (@$ds_ids) {
	    my $sql = qq{ select distinct n.name, ds.name dataitem, s.is_move, sp.is_custodial
			      from t_adm_node n
			      join t_dps_subs_dataset s on s.destination = n.id
			      join t_dps_dataset ds on ds.id=s.dataset
			      join t_dps_subs_param sp on s.param=sp.id
			      where s.dataset = :dataset
			  UNION
			  select distinct n.name, bk.name dataitem, s.is_move, sp.is_custodial
			      from t_adm_node n
			      join t_dps_subs_block s on s.destination = n.id
			      join t_dps_block bk on bk.id=s.block
			      join t_dps_dataset ds on ds.id=s.dataset
			      join t_dps_subs_param sp on s.param=sp.id
			      where s.dataset = :dataset
			      and bk.time_create>nvl(:time_start,-1)
			  };
	    foreach my $ds (@$ds_ids) {  
		my $other_subs = &execute_sql($self, $sql, ':dataset' => $ds, ':time_start' => $h{TIME_START});
                while (my $r = $other_subs->fetchrow_hashref()) {                           
		    if ((grep (/^$r->{NAME}$/, @$nodes)) && ($r->{IS_CUSTODIAL} ne $h{IS_CUSTODIAL})) {
                        die "cannot request transfer: $r->{DATAITEM} already subscribed to $r->{NAME} with different custodiality\n";
                    }
		    elsif ((grep (/^$r->{NAME}$/, @$nodes)) && ($r->{IS_MOVE} eq 'y') && ($h{IS_MOVE} eq 'n')) {
			die "cannot request replica transfer: $r->{DATAITEM} already subscribed to $r->{NAME} as move\n";
		    }
                    $sources{$r->{NAME}}=1;
                }
	    }
	    
	} 
	
	if (@$b_ids) {
	    my $sql = qq{ select distinct n.name, ds.name dataitem, s.is_move, sp.is_custodial
			      from t_adm_node n
			      join t_dps_subs_dataset s on s.destination = n.id
			      join t_dps_block bk on bk.dataset = s.dataset
			      join t_dps_dataset ds on ds.id = s.dataset
			      join t_dps_subs_param sp on s.param = sp.id
			      where bk.id = :block and bk.time_create > nvl(s.time_fill_after,-1)
			   UNION
			   select distinct n.name, bk.name dataitem, s.is_move, sp.is_custodial
			      from t_adm_node n
			      join t_dps_subs_block s on s.destination = n.id
			      join t_dps_block bk on bk.id=s.block
			      join t_dps_subs_param sp on s.param=sp.id
			      where s.block = :block
			      and bk.time_create>nvl(:time_start,-1)
			  };
	    foreach my $b (@$b_ids) {
		my $other_subs = &execute_sql($self, $sql, ':block' => $b, ':time_start' => $h{TIME_START});
		while (my $r = $other_subs->fetchrow_hashref()) {
		    if ((grep (/^$r->{NAME}$/, @$nodes)) && ($r->{IS_CUSTODIAL} ne $h{IS_CUSTODIAL})) {
                        die "cannot request transfer: $r->{DATAITEM} already subscribed to $r->{NAME} with different custodiality\n";
                    }
		    elsif ((grep (/^$r->{NAME}$/, @$nodes)) && ($r->{IS_MOVE} eq 'y') && ($h{IS_MOVE} eq 'n')) {
			die "cannot request replica transfer: $r->{DATAITEM} already subscribed to $r->{NAME} as move\n";
		    }
		    $sources{$r->{NAME}}=1;
		} 
	    }
	}
	if ($h{IS_MOVE} eq 'y') {
	    if (grep $_ !~ /^T[01]_.*_(MSS|Disk)$/, @$nodes) {
		die "cannot request move:  moves to non-T0, non-T1 destinations are not allowed\n";
	    }
	    # Exclude T0/T1 nodes from list of source nodes that will receive deletion request for move
	    delete @sources{grep /^(T1.*(Buffer|MSS)|T0.*(Export|MSS))/, keys %sources};
	    # Should not be possible given the previous step, but reject move request if it still contains
	    # T0/T1 nodes as source points
	    die "cannot request move:  moves of data subscribed to T0 or T1 are not allowed\n"
		if grep /^(T1.*(Buffer|MSS)|T0.*(Export|MSS))/, keys %sources;
	    push @node_pairs, map { [ 's', $nodemap{$_} ] } keys %sources;
	}

    }

    return ($ds_ids, $b_ids, \@node_pairs, %h);
}

=pod

=item createRequest($self, $ds_ids, $b_ids, $node_pairs, %h)

Takes arguments returned by validateRequest. Creates a new request.
Returns the newly created request id.

=cut

sub createRequest
{
    #my ($self, $ds_ids, $b_ids, $f_ids, $node_pairs, %h) = @_;
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
			   is_transient, is_distributed, user_group, time_start, data)
			  values
			  (:request, :priority, :is_custodial, :is_move, :is_static,
			   :is_transient, :is_distributed, :user_group, :time_start, :data) };
	my %binds;
	$binds{':request'} = $rid;
	$binds{lc ":$_"} = $h{$_} foreach qw(PRIORITY IS_CUSTODIAL IS_MOVE IS_STATIC
					     IS_TRANSIENT IS_DISTRIBUTED TIME_START DATA);
	
	my $group_id = &validateGroup($self,$h{USER_GROUP});
	if ($group_id) {
	    $binds{':user_group'} = $group_id;
	} else { 
	    die "cannot create request: USER_GROUP $h{USER_GROUP} not found\n";
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

=head1 SEE ALSO

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>

=cut

1;

