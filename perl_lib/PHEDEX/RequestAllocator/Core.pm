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
    foreach my $req (qw(CLIENT_ID TYPE FORMAT)) {
	die "required parameter $req is not defined\n"
	    unless exists $h{$req} && defined $h{$req};
    }

    my @typereq;
    if ( $h{TYPE} eq 'xfer' ) { 
	@typereq = qw( PRIORITY IS_MOVE IS_STATIC IS_TRANSIENT IS_DISTRIBUTED ); 
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
	foreach my $ds (values %{$dbs->{DATASETS}}) {
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
    execute_sql($self,
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
	execute_sql($self, $sql, %binds);
    } elsif ($type eq 'delete') {
	my $sql = qq{ insert into t_req_delete
			  (request, rm_subscriptions, data)
			  values
			  (:request, :rm_subscriptions, :data) };
	my %binds;
	$binds{':request'} = $rid;
	$binds{lc ":$_"} = $h{$_} foreach qw(RM_SUBSCRIPTIONS DATA);
	execute_sql($self, $sql, %binds);
    }
    
    # Write the comment
    if ($h{COMMENTS}) {
	my $comments_id = &writeRequestComments($self, $rid, $h{CLIENT_ID}, $h{COMMENTS}, $now);
	execute_sql($self, qq[ update t_req_request set comments = :comments_id where id = :rid ],
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
