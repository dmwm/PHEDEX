package PHEDEX::BlockDLSUpdate::Agent;

=head1 NAME

PHEDEX::BlockDLSUpdate::Agent - the Block DLS Update agent.

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Agent';
use File::Path;
use Data::Dumper;
use PHEDEX::Core::Command;
use PHEDEX::Core::Logging;
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;
use PHEDEX::Core::JobManager;
use DB_File;

our %params =
	(
	  DBCONFIG => undef,		# Database configuration file
	  WAITTIME => 3600,		# Agent activity cycle
	  NODES => [ '%' ],		# Nodes this agent runs for
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = $class->SUPER::new(@_);
  foreach ( keys %params )
  {
    $self->{$_} = $params{$_} unless defined $self->{$_};
  }

  bless $self, $class;
  return $self;
}

# Pick up ready blocks from database and inform downstream agents.
sub idle
{
    my ($self, @pending) = @_;
    my $dbh;
    # tie state file
    my %state;
    tie %state, 'DB_File', "$$self{DROPDIR}/state.dbfile"
	or die "Could not tie state file:  $!\n";

    eval
    {
	# Connect to database
	my @nodes = ();
	$self->{NODES} = [ '%' ];
	($dbh, @nodes) = &expandNodesAndConnect ($self);
	my ($my_nodes, %my_args) = &myNodeFilter ($self, "br.node");

	# Get order list of blocks we have.  This is always everything,
	# but we keep track of what we've updated in a file.  If the
	# agent is started without the file existing it will try to
	# update everything.
	# Downstream users of this information must handle duplicates.
        my $completed = &dbexec ($dbh, qq{
	    select dbs.name dbs_name,
	           dbs.dls dls_name,
	           b.name block_name,
	           b.id block_id,
	           n.name node_name,
	           n.id node_id,
		   n.se_name se_name,
	           'dls-add' command
	    from t_dps_block_replica br
	      join t_dps_block b on b.id = br.block
	      join t_dps_dataset ds on ds.id = b.dataset
	      join t_dps_dbs dbs on dbs.id = ds.dbs
	      join t_adm_node n on n.id = br.node
	    where $my_nodes
  	      and b.is_open = 'n'
	      and br.dest_files = b.files
	      and br.node_files = b.files
	      and dbs.dls is not null
	      and n.se_name is not null},
	    %my_args)
	    ->fetchall_arrayref({});


        my $deleted = &dbexec ($dbh, qq{
	    select dbs.name dbs_name,
	           dbs.dls dls_name,
	           b.name block_name,
	           b.id block_id,
	           n.name node_name,
	           n.id node_id,
		   n.se_name se_name,
	           'dls-delete' command
	    from t_dps_block_delete bd
	      join t_dps_block b on b.id = bd.block
              join t_dps_block_replica br on br.block = b.id
	      join t_dps_dataset ds on ds.id = b.dataset
	      join t_dps_dbs dbs on dbs.id = ds.dbs
	      join t_adm_node n on n.id = bd.node
	    where $my_nodes
  	      and b.is_open = 'n'
	      and bd.time_complete is not null
	      and dbs.dls is not null
	      and n.se_name is not null},
	    %my_args)
	    ->fetchall_arrayref({});

        # Get the ID for DBS test-requests from the t_dvs_test table.
	my $test = PHEDEX::BlockConsistency::SQL::get_TDVS_Tests($self,'dbs')->{ID};

	foreach my $block (@$completed, @$deleted)
        {
	    # If we've updated already, skip this
	    my $cachekey = "$$block{COMMAND} $$block{DBS_NAME} $$block{BLOCK_NAME} $$block{NODE_NAME}";
	    next if exists $state{$cachekey} && $state{$cachekey} > 0;
	    $state{$cachekey} = -1;

	    # If it is a deletion command, remove addition command from cache
	    if ( $$block{COMMAND} eq 'dls-delete') {
		my $addkey = $cachekey;
		$addkey =~ s/dls-delete/dls-add/;
		delete $state{$addkey} if exists $state{$addkey};
	    }

	    # Queue the block for consistency-checking. Ignore return values
            if ( $block->{COMMAND} eq 'dls-add' )
            {
              PHEDEX::BlockConsistency::Core::InjectTest
			( $dbh,
			  block       => $block->{BLOCK_ID},
			  test        => $test,
			  node        => $block->{NODE_ID},
			  n_files     => 0,
			  time_expire => 10 * 86400,
			  priority    => 1,
			  use_srm     => 'n',
			);
            }

	    # Decompose DLS contact into arguments accepted by DLS API.
	    my ($dlstype, $sep, $contact) = ($block->{DLS_NAME} =~ m|^([a-z]+)(://)?(.*)|);

	    my $dls_iface;
	    if ($dlstype eq 'lfc') { $dls_iface = 'DLS_TYPE_LFC'; }
	    elsif ($dlstype eq 'mysql') { $dls_iface = 'DLS_TYPE_MYSQL'; }
	    elsif ($dlstype eq 'dbs') { 
		$dls_iface = 'DLS_TYPE_DBS';
		$contact = $block->{DBS_NAME} unless $contact;
	    } else {
		&alert ("dls contact $$block{DLS_NAME} not understood");
		next;
	    }

	    # Now modify DLS.  If the command fails, alert but
	    # keep going.
	    my $log = "$$self{DROPDIR}/$$block{SE_NAME}.$$block{BLOCK_ID}.log";
	    my @cmd = ("$$block{COMMAND}", "-i", $dls_iface,
		       "-e", $contact, $$block{BLOCK_NAME}, $$block{SE_NAME});
	    
	    $self->addJob(sub { $self->registered ($block, \$state{$cachekey}, @_) },
		          { TIMEOUT => 30, LOGFILE => $log },
		          @cmd);
        }
    };
    do { chomp ($@); &alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh } if $@;

    # Disconnect from the database
    &disconnectFromDatabase ($self, $dbh, 1);

    # Wait for all jobs to finish
    while (@{$self->{JOBS}})
    {
        $self->pumpJobs();
        select (undef, undef, undef, 0.1);
    }

    # untie
    untie %state;

    # Have a little nap
    $self->nap ($self->{WAITTIME});
}

# Handle finished jobs.
sub registered
{
    my ($self, $block, $state, $job) = @_;
    if ($job->{STATUS})
    {
	&warn("failed to $$block{COMMAND} block $$block{BLOCK_NAME} for"
	      . " $$block{NODE_NAME}, log in $$job{LOGFILE}");
    }
    else
    {
	&logmsg("Successfully issued $$block{COMMAND}"
		. " on block $$block{BLOCK_NAME} for $$block{NODE_NAME}");
	unlink ($job->{LOGFILE});
	$$state = &mytimeofday();
    }
}

sub isInvalid
{
  my $self = shift;
  my $errors = $self->SUPER::isInvalid
                (
                  REQUIRED => [ qw / DROPDIR DBCONFIG / ],
                );
  return $errors;
}

1;
