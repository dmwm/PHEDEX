package PHEDEX::Monitoring::InvariantMonitor::Agent;
use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
		  MYNODE => undef,		# My TMDB node name
	          WAITTIME => 60*15,		# Agent activity cycle
		  ME	=> 'InvariantMonitor',
		 );
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Called by agent main routine before sleeping.  Run invariant checks
sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;
    eval
    {
	$dbh = $self->connectAgent();
	my $now = &mytimeofday();	
	# I:  Broken paths
	# Invaraint:  The number of paths missing hops should be zero.
	my $q = &dbexec($dbh, qq{
         select count(*)
                -- xp.fileid, xp.hop,
                -- xp.src_node source,
                -- xp.destination,
                -- xp_prev.to_node prev_to, xp.from_node, xp.to_node, xp_next.from_node next_from
          from t_xfer_path xp 
     left join t_xfer_path xp_prev on xp_prev.fileid = xp.fileid
                                      and xp_prev.to_node = xp.from_node
     left join t_xfer_path xp_next on xp_next.fileid = xp.fileid
                                      and xp_next.from_node = xp.to_node
         where (xp_prev.fileid is null and xp.from_node != xp.src_node)
            or (xp_next.fileid is null and xp.to_node != xp.destination)
	});
	my ($broken_count) = $q->fetchrow();
	if ($broken_count != 0) {
	    $self->Logmsg ("$broken_count broken paths.");
	}

	# II:  Unfinished blocks
	# Invariant:  Blocks marked "done" have src_files = node_files
	$q = &dbexec($dbh, qq{
	    select count(*) 
		--br.block, br.dest_files, br.node_files, br.node, br.is_active
              from t_dps_block_replica br
              join t_dps_block_dest bd on bd.block = br.block and bd.destination = br.node
             where bd.state = 3 and br.dest_files != br.node_files
	 });
	my ($not_done_count) = $q->fetchrow();
	if ($not_done_count != 0) {
	    $self->Logmsg("$not_done_count blocks marked done with files still to transfer");
	}

	# III:  Activate (transfer) blocks not active
	# Invariant:  Blocks marked active but are missing files in t_xfer_request and t_xfer_replica
	$q = &dbexec($dbh, qq{
	    select count(*)
              from t_dps_block_dest bd 
              join t_xfer_file xf on xf.inblock = bd.block
         left join t_xfer_request xq on xq.fileid = xf.id and xq.destination = bd.destination
         left join t_xfer_replica xr on xr.fileid = xf.id and xr.node = bd.destination
	 where bd.state = 1 and (xq.fileid is null and xr.fileid is null) 
     });
	
	my ($bad_active_count) = $q->fetchrow();
	if ($bad_active_count != 0) {
	    $self->Logmsg("$bad_active_count files not active from an active block");
	}

	# IV:  Deactivated (collapsed) blocks have active files
	# Invariant:  if br.is_active = 'n' then there shall be no files of that block in t_xfer_file
	$q = &dbexec($dbh, qq{
           select count(distinct xf.id)
            from t_dps_block_replica br
            join t_xfer_file xf on xf.inblock = br.block
           where br.is_active = 'n'
       });
	
	my ($bad_inactive_count) = $q->fetchrow();
	if ($bad_inactive_count != 0) {
	    $self->Logmsg("$bad_inactive_count files active from inactive blocks");
	}

        # V:  Activate (expanded) blocks have no active files
	# Invariant:  if br.is_active = 'y' then there shall be files of that block in t_xfer_file
	$q = &dbexec($dbh, qq{
	    select count(distinct b.id) 
              from t_dps_block b
              join t_dps_block_replica br on br.block = b.id where br.is_active = 'y'
               and not exists (select 1 from t_xfer_file where inblock = b.id) 
       });
	
	my ($bad_active_exp_count) = $q->fetchrow();
	if ($bad_active_exp_count != 0) {
	    $self->Logmsg("$bad_active_exp_count active blocks with no active files");
	}


    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;
    
    # Disconnect from the database
    $self->disconnectAgent();
}

1;
