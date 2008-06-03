package PHEDEX::RequestAllocator::Agent;

=head1 NAME

PHEDEX::RequestAllocator::Agent - expands requests into subscriptions

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging', 'PHEDEX::RequestAllocator::SQL';
use PHEDEX::Core::Timing;

our %params =
	(
	  MYNODE => undef,              # my TMDB nodename
    	  DBCONFIG => undef,		# Database configuration file
	  WAITTIME => 15*60,            # Agent cycle time
	  VERBOSE    => $ENV{PHEDEX_VERBOSE} || 0,
	  ME	     => 'RequestAllocator',
	);

our @array_params = qw / MYARRAY /;
our @hash_params  = qw / MYHASH /;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(%params,@_);
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

=head1 Overriding base-class methods

The methods provided here are all used in the base Agent class, and can be
overridden to specialise the agent. You can call the base class method in your
ovverride or, if you only need the base class behaviour, simply don't provide
the method in your agent.

These sample overrides just print their entry and exit, and call the base class
method o provide a minimal functioning agent.

=head2 init

The C<< init >> method is used to fully initialise the object. This is separate
from the constructor, and is called from the C<< process >> method. This gives
you a handle on things between construction and operation, so if we go to
running more than one agent in a single process, we can do things between the
two steps.

One thing in particular that the C<< init >> method can handle is string values
that need re-casting as arrays or hashes. We currently hard-code arrays such as
C<< IGNORE_NODES >> in our agents, but that can now be passed directly to the
agent in the constructor arguments as a string. The C<< init >> method in the
base class takes a key-value pair of 'ARRAYS'-(ref to array of strings). The
strings in the ref are taken as keys in the object, and, if the corresponding
key is set, it is turned into an array by splitting it on commas. If the key
is not set in the object, it is set to an empty array. This way,
C<< IGNORE_NODES >> and its cousins can be passed in from a configuration file
or from the command line. See C<< perl_lib/template/Agent.pl >> for an example
of how to do this, commented in the code.

=cut

sub init
{
  my $self = shift;

  print $self->Hdr,"entering init\n";
# base initialisation
  $self->SUPER::init(@_);

# Now my own specific values...
  $self->SUPER::init
	(
	  ARRAYS => [ @array_params ],
	  HASHES => [ @hash_params ],
	);
  print $self->Hdr,"exiting init\n";
}

=head2 idle

Pick up work from the database and start site specific scripts if necessary

=cut
sub idle
{
  my $self = shift;
  my $dbh;

  eval
  {
    $dbh = $self->connectAgent();
    my $now = &mytimeofday ();
    
    # Get transfer requests which need to be re-evaluated
    my $xfer_reqs = $self->getTransferRequests( APPROVED  => 1,
						STATIC    => 0,
						WILDCARDS => 1,
						DEST_ONLY => 1
						);
    
    # Expand each request into subscriptions, check the expanded items
    # against later deletion requests, and create the subscriptions
    foreach my $xreq ( values %$xfer_reqs ) {
	my $dest_nodes = [ keys %{ $xreq->{NODES} } ];
	my ($datasets, $blocks) = $self->expandRequest( $xreq->{DATA} );

	my $subscribe = $self->distributeData( NODES => $dest_nodes,
					       DATASETS => $datasets,
					       BLOCKS => $blocks );

	my $del_reqs  = $self->getDeleteRequests( APPROVED => 1,
						  RETRANSFER => 0,
						  AFTER => $xreq->{TIME_CREATE},
						  NODES => $dest_nodes );
	
	# Find all the data we need to skip
	my ($ex_ds, $ex_b) = $self->getExistingRequestData( $xreq->{ID} );
	my $skip = { DATASET => $ex_ds || [],
		     BLOCK   => $ex_b  || [] };

	foreach my $dreq ( @$del_reqs ) {
	    my ($del_ds, $del_b) = $self->getExistingRequestData( $dreq->{ID} );
	    push @{$skip->{DATASET}}, @$del_ds;
	    push @{$skip->{BLOCK}}, @$del_b;
	}
	
	foreach my $subn ( @$subscribe ) {
	    my ($type, $node, $id) = @$subn;
	    next if grep $id == $_, @{ $skip->{$type} };
	    $self->addRequestData( $xreq->{ID}, $type => $id );
	    $self->createSubscription( NODE => $node, $type => $id, REQUEST => $xreq->{ID} );
	}
    }

  };
  do { chomp ($@); $self->Alert ("database error: $@");
       eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database
    $self->disconnectAgent();
}

# Expands a request (user field of data items) into data/node pairs
# which can be used to create subscriptions or deletions.
sub expandRequest
{
    my ($self, $data, %opts) = @_;
    
    my %data = &parseUserData($data);
    my @dataset_patterns;
    my @block_patterns;
    while (my ($item, $level) = each %data) {
	next unless $level; # undefined level means bad data format
	my $pat = $item;
	$pat =~ s/\**/%/g; # replace '*' with sql '%'
	push @dataset_patterns, $pat if $level eq 'DATASET';
	push @block_patterns, $pat if $level eq 'BLOCK';
    }

    my $sql;
    my (@datasets, @blocks);
    if (@dataset_patterns && $opts{DATASETS_TO_BLOCKS} ) {
	$sql = qq{ select b.id
		       from t_dps_dataset ds
		        join t_dps_block b on b.dataset = ds.id
		       where ds.name like :dataset };

	foreach (@dataset_patterns) {
	    my $b = select_single ($self->{DBH}, $sql, ':dataset' => $_);
	    push @blocks, @$b;
	}

    } elsif (@dataset_patterns) {
	$sql = qq{ select ds.id
			  from t_dps_dataset ds
			  where ds.name like :dataset };

	foreach (@dataset_patterns) {
	    my $ds = select_single ($self->{DBH}, $sql, ':dataset' => $_);
	    push @datasets, @$ds;
	}

    }

    # expand block patterns into blocks
    $sql = qq{ select b.id
                 from t_dps_block b
	        where b.name like :block };

    foreach (@block_patterns) {
	my $b = select_single ($self->{DBH}, $sql, ':block' => $_);
	push @blocks, @$b;
    }

    return (\@datasets, \@blocks);

}

# Takes an array of user data clobs and parses out single dataset and block globs
# Returns a hash of key:  glob pattern value: item type (DATASET or BLOCK)
sub parseUserdata
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
    my ($self, $opts) = @_;
    unless ($opts->{NODES} && ($opts->{DATASETS} || $opts->{BLOCKS})) {
	die "distributeData requires NODES and (DATASETS or BLOCKS)";
    }

    my %items;
    $items{DATASET} = $opts->{DATASETS} if $opts->{DATASETS} && ref $opts->{DATASETS} eq 'ARRAY';
    $items{BLOCK} = $opts->{BLOCKS} if $opts->{BLOCKS} && ref $opts->{BLOCKS} eq 'ARRAY';

    my $dist = [];
    # Distribute to all nodes
    foreach my $node (@{ $opts->{NODES} }) {
	foreach my $type ( keys %items ) {
	    foreach my $id ( @{ $items{$type} } ) {
		push @$dist, [$type, $node, $id];
	    }
	}
    }
    
    return $dist;
}



=head2 isInvalid

The isInvalid method is intended to validate the object structure/contents,
and is called from the PHEDEX::Core::Agent::process method. Return non-zero
for failure, and the agent will die.

You can use the parent PHEDEX::Core::Agent::IsInvalid method for routine
checking of the existence and type-validity of members variables, and add
your own specific checks here. The intent is that isInvalid should be
callable from anywhere in the code, should you wish to do such a thing, so
it should not have side-effects, such as changing the object contents or state
in any way. If you need to initialise an object further than you can in
C<< new >>, use the C<< init >> method to set it up.

You do not need to validate the basic PHEDEX::Core::Agent object, that will
already have happened in the constructor.

=cut
sub isInvalid
{
  my $self = shift;
  my $errors = 0;
  print $self->Hdr,"entering isInvalid\n" if $self->{VERBOSE};
  print $self->Hdr,"exiting isInvalid\n" if $self->{VERBOSE};

  return $errors;
}

1;
