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
    while (my ($item, $level) = each %data) {
	next unless $level; # undefined level means bad data format
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
    
    return (\@datasets, \@blocks);

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

=pod

=item createRequest($self, $data, $nodes, %args)

Creates a new request, returns the newly created request id.

TODO:  document format for $data and $nodes hash.

=cut

sub createRequest
{
    my ($self, $data, $nodes, %h) = @_;

    # check parameters
    foreach my $req (qw(CLIENT_ID TYPE TYPE_ATTR)) {
	die "createRequest:  required parameter $req is not defined\n"
	    unless exists $h{$req} && defined $h{$req};
    }

    my @typereq;
    if ( $h{TYPE} eq 'xfer' ) { 
	@typereq = qw( PRIORITY IS_MOVE IS_STATIC IS_TRANSIENT IS_DISTRIBUTED ); 
    } elsif ( $h{TYPE} eq 'delete' ) {
	@typereq = qw( RM_SUBSCRIPTIONS );
    } else {
	die "createRequest:  TYPE '$h{TYPE}' is not valid\n";
    }
    foreach my $req (@typereq) {
	die "createRequest: required $h{TYPE} parameter $req is not defined\n"
	    unless exists $h{TYPE_ATTR}->{$req} && defined $h{TYPE_ATTR}->{$req};
    }

    my $type = $h{TYPE};
    my $type_attr = $h{TYPE_ATTR};
    my $client = $h{CLIENT_ID};
    my $expand_datasets = $type eq 'xfer' && $type_attr->{IS_STATIC} eq 'y' ? 1 : 0;
    my $now = $h{NOW} || &mytimeofday();
    my @ids;

    # iterate through data structre and create request
    foreach my $dbs (values %{$data->{DBS}}) {
	my $db_dbs = &getDbsFromName($self, $dbs->{NAME});
	if (! $db_dbs->{ID} ) {
	    die "dbs '$dbs->{NAME}' does not exist\n";
	}

	# Write the request
	my $rid;
	execute_sql($self,
		    qq[	insert into t_req_request (id, type, created_by, time_create)
			values (seq_req_request.nextval, (select id from t_req_type where name = :type),
				:client, :now )
			returning id into :id ],
		    ':id' => \$rid, ':type' => $type, ':client' => $client, ':now' => $now);

	# Write the (resolved) dbs/datasets/blocks to the DB
	&execute_sql($self, 
		    qq[ insert into t_req_dbs (request, name, dbs_id)
			values (:rid, :dbs_name, :dbs_id) ],
		     ':rid' => $rid, ':dbs_name' => $db_dbs->{NAME}, ':dbs_id' => $db_dbs->{ID});

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

	# Make a data clob for storage
	$type_attr->{DATA} = join("\n", @datasets, @blocks);

	# TODO: improve efficiency by rewriting expandDataClob to take
	#       already parsed data patterns instead of a clob?
	my (%uniq_ds, %uniq_b);
	my (@null);
	foreach my $item (@datasets, @blocks) {
	    my ($ds_ids, $b_ids) = &expandDataClob($self, $db_dbs->{ID}, $item,
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

	if ( %uniq_ds || %uniq_b ) {
	    &addRequestData($self, $rid, DATASET => $_) foreach keys %uniq_ds;
	    &addRequestData($self, $rid, BLOCK => $_) foreach keys %uniq_b;
	} else {
	    die "request matched no data in TMDB\n";
	}

	# Request policy details here:
	#  * Moves may only be done to a T1 MSS node
	#  * Moves can not be done when data is subscribed at a T1
	my @node_pairs;
	my %nodemap = reverse %{ &getNodeMap($self) };
	if ($type eq 'delete') {
	    # deletion requests do not define endpoints
	    @node_pairs = map { [ undef, $nodemap{$_} ] } @$nodes;
	} elsif ($type eq 'xfer') { # user specifies destinations
	    @node_pairs = map { [ 'd', $nodemap{$_} ] } @$nodes;
	    # already subscribed nodes for the data specify sources for move requests
	    if ($type_attr->{IS_MOVE} eq 'y') {
		if (grep $_ !~ /^T1_.*_MSS$/, @$nodes) {
		    die "cannot request move:  moves to non-T1 destinations are not allowed\n";
		}

		my $src_sql = qq{ select distinct n.name
                                   from t_adm_node n
                                   join t_dps_subscription s on s.destination = n.id
                                   join t_dps_block sb on sb.dataset = s.dataset or sb.id = s.block
                                  where sb.id in ( 
                                          select b.id 
                                            from t_req_dataset rds
                                            join t_dps_block b on b.dataset = rds.dataset_id
                                           where rds.request = :rid
                                           union
                                          select block_id from t_req_block
					   where request = :rid
				        ) 
			      };
						  
		my @other_subs = @{ &select_single($self, $src_sql, ':rid' => $rid) };
		if (grep /^T1/, @other_subs) {
		    # TODO:  when custodial flag is here, it should determine this restriction
		    die "cannot request move:  moves of data is subscribed to a T1 are not allowed\n";
		}
		push @node_pairs, map { [ 's', $nodemap{$_} ] } @other_subs;
	    }
	}

	# Write the nodes involved
	my $i_node = &dbprep($self->{DBH},
			     qq[ insert into t_req_node (request, node, point)
				 values (:rid, :node, :point) ]);
	foreach my $pair (@node_pairs) {
	    my ($endpoint, $node_id) = @$pair;
	    &dbbindexec($i_node,
			':rid' => $rid,
			':node' => $node_id,
			':point' => $endpoint);
	}

	# Write the request type parameters
	my $table = 't_req_'. $type;
	my @columns = ('request', sort keys %$type_attr);
	my $sql = "insert into $table (" . join(', ', @columns) . ")" .
	    " values (" . join(', ', map { ":$_" } @columns) . ")";
	my %binds = ( ':request' => $rid );
	$binds{":$_"} = $type_attr->{$_} foreach keys %$type_attr;
	execute_sql($self, $sql, %binds);
	
	# Write the comment
	if ($h{COMMENTS}) {
	    my $comments_id = &writeRequestComments($self, $rid, $client, $h{COMMENTS}, $now);
	    execute_sql($self, qq[ update t_req_request set comments = :comments_id where id = :rid ],
			':rid' => $rid, ':comments_id' => $comments_id);
	}
	push @ids, $rid;
    } # /dbs

    return @ids;
}

=pod

=back

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,

=cut

1;
