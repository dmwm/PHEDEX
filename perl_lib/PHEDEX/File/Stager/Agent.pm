package PHEDEX::File::Stager::Agent;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';

use strict;
use warnings;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::DB;

sub min { return (sort { $a <=> $b } @_)[0] }
sub max { return (sort { $b <=> $a } @_)[0] }

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
	  	  NODES => undef,		# Nodes this agent runs for
		  IGNORE_NODES => ['%_MSS'],    # TMDB nodes to ignore
		  ACCEPT_NODES => [],           # TMDB nodes to accept
	  	  PROTECT_CMD => undef,		# Command to check for overload
		  STAGE_CMD => undef,	        # Command to trigger prestage
		  STATUS_CMD => undef,	        # Command to check staging status
		  MAXFILES => 100,		# Max number of files in one request in one cycle
		  TIMEOUT => 600,               # Timeout for commands
		  STAGE_STALE => 8*3600,        # Age after which the stage cache is stale
	  	  STORAGEMAP => undef,		# Storage path mapping rules
		  PROTOCOL => {},               # TFC protocol to build the PFNs (direct, smrv2, etc)
		  WAITTIME => 550 + rand(100),  # Agent cycle time
	  	  ME => "FileStager", 	        # Identity for activity logs
		  PFN_CACHE => {},		# LFN -> PFN cache
		  STAGE_CACHE => {},		# Stage status cache
		  DB_CACHE => {},		# Cache of DB state
		 );
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;

    bless $self, $class;
    return $self;
}

# Prepend commands with RunWithTimout utility
sub timeout_cmd
{
    my ($timeout, @cmd) = @_;
    $timeout ||= 60;

    my $pfx = $0;
    $pfx =~ s|/[^/]+$||;
    $pfx .= "/../../Utilities/RunWithTimeout";

    return ($pfx,$timeout,@cmd);
}


# Purge old entries from our caches.
sub purgeCache
{
    my ($cache, $lifetime) = @_;
    $lifetime ||= 86400;

    # Remove old positive matches after a day to avoid building up
    # a cache over a time.  Remove negative matches after an hour.
    my $now = time ();
    my $oldmatch = $now - $lifetime;
    my $oldnomatch = $now - 3600;

    # Remove entries that are too old
    foreach my $item (keys %$cache)
    {
	delete $$cache{$item}
	if ($$cache{$item}{TIME} < $oldmatch
	    || (! $$cache{$item}{VALUE}
		&& $$cache{$item}{TIME} < $oldnomatch));
    }
}

# Get the list of files in transfer out of the node.
sub getNodeFiles
{
    my ($self, $dbh) = @_;
    my %files = ();

    # First fetch files coming out of our node from the database.  
    # If we come across something we haven't seen before, remember it
    # but don't look it up yet.  We get files exported from the node,
    # plus most recent time the file was in that state.
    my ($mynodes, %myargs) = $self->myNodeFilter ("xt.from_node");
    my ($dest, %dest_args) = $self->otherNodeFilter ("xt.to_node");
    my $stmt = &dbexec($dbh, qq{
	select f.logical_name from t_xfer_task xt
	    join t_adm_link l on l.from_node = xt.from_node and l.to_node = xt.to_node
	    join t_xfer_file f on f.id = xt.fileid
	    where $mynodes $dest}, %myargs, %dest_args);
    $files{$_} = { LFN => $_, PFN => undef, TIME => 0 }
    while (($_) = $stmt->fetchrow());

    # Now, collect PFNs for cached files.
    foreach my $lfn (keys %files)
    {
	$files{$lfn}{PFN} = $$self{PFN_CACHE}{$lfn}{VALUE}
	if exists $$self{PFN_CACHE}{$lfn};
    }
    
    # Finally PFNs for files not in cache.  We do this in single
    # efficient pull + cache results.
    if (my @lfns = grep(! $files{$_}{PFN}, keys %files))
    {
        my $now = time();
        my $pfns = &pfnLookup (\@lfns, $$self{PROTOCOL}, "local", $$self{STORAGEMAP});
	while (my ($lfn, $pfn2) = each %$pfns)
        {
	    my $pfn = $pfn2->[1];
	    # HOW DO I PASS SPACE-TOKEN?
	    my $space_token = $pfn2->[0];
	    $$self{PFN_CACHE}{$lfn} = { TIME => $now, VALUE => $pfn }; 
	    $files{$lfn}{PFN} = $pfn if defined $pfn;
        }
    }
    
    return \%files;
}

# Append into the file list the stager status information.
# Returns undef if the stager can't be queried because of
# a transient error.  Otherwise returns the input hash.
sub getStagerFiles
{
    my ($self, $files) = @_;
    return undef if ! $files;
    
    # First check which files don't have a cached stager status.
    my @todo = ();
    my $now = time();
    foreach my $file (values %$files)
    {
	my $pfn = $$file{PFN};
	next if ! $pfn;
	my $c = $$self{STAGE_CACHE}{$pfn};
        $$file{STATUS} = $$c{VALUE} if $$c{VALUE};
	do {push (@todo, $file);} 
	if (($c && $$c{VALUE}) || '') ne 'STAGED';
    }

    # Now, look up stager status for the files invoking the prestage status command
    # passing a bunch of files at a time. It returns only files staged.
    # Update the file status in the cache.
    # Since the external command for checking the staging status could hang, blocking
    # the agent from making progress, run the command using a timeout.
    while (@todo)
    {
	
	my @slice = splice(@todo, 0, $$self{MAXFILES});
	my %pfn2f = map { ($$_{PFN} => $_) } @slice;       
	my @pfns =  map { "$$_{PFN}" } @slice;
        my $nfiles = scalar @slice;
        $self->Logmsg ("Checking staging status of $nfiles pending files");
	my @cmd = &timeout_cmd($$self{TIMEOUT}, @{$$self{STATUS_CMD}}, @pfns);
	open (QRY, "@cmd |")
	    or do { $self->Alert ("@{$$self{STATUS_CMD}}: cannot execute: $!"); return undef };
	while (<QRY>)
	{
	    chomp;
	    next if ! /^(\S+)$/;
	    do { $self->Alert ("@{$$self{STATUS_CMD}} output unrecognised file $_"); next }
	    if ! exists $pfn2f{$1};
            $self->Logmsg ("$1 STAGED");
	    $$self{STAGE_CACHE}{$1} = { TIME => time(), VALUE => "STAGED" };
	}
	close (QRY);
    }
    
    return $files;
}

# Build status object from stager state and pending requests.
sub buildStatus
{
    my ($self, $files) = @_;
    return undef if ! $files;
    
    # Mark in unknown state all files without clear status.
    foreach my $file (values %$files)
    {
	do { $self->Warn ("unknown wanted file $$file{LFN}"); next }
	if ! $$file{PFN};
	$$file{STATUS} ||= "UNKNOWN";
    }

    return $files;
}

# Called by agent main routine before sleeping.  Pick up stage-in
# assignments and map current stager state back to the database.
sub idle
{
    my ($self, @pending) = @_;

    my $dbh = undef;
    eval
    {
	my $rc;
	if ($$self{PROTECT_CMD} && ($rc = &runcmd(@{$$self{PROTECT_CMD}})))
	{
	    $self->Alert("storage system overloaded, backing off"
			 . " (exit code @{[&runerror($rc)]})");
	    return;
	}
	
	$dbh = $self->connectAgent();
	my @nodes = $self->expandNodes();
	my ($mynodes, %myargs) = $self->myNodeFilter ("node");
	
	# Clean up caches
	my %timing = (START => &mytimeofday());
	&purgeCache ($$self{PFN_CACHE});
	&purgeCache ($$self{STAGE_CACHE}, $$self{STAGE_STALE});
	$timing{PURGE} = &mytimeofday();

	# Get pending and stager files
	my $files = $self->getNodeFiles ($dbh);
	return if ! $self->getStagerFiles ($files);
	return if ! $self->buildStatus ($files);
	$timing{STATUS} = &mytimeofday();

	# Update file status.  First mark everything not staged in,
	# then as staged-in the files currently in stager catalogue.
	# However, remember the status of the files we have updated
	# in the database in the last 4 hours, and only mark a delta.
	my $now = time();
	my $dbcache = $$self{DB_CACHE};
	if (($$dbcache{VALIDITY} || 0) < $now)
	{
	    $$dbcache{VALIDITY} = $now + 12*3600;
	    $$dbcache{FILES} = {};
	    &dbexec($dbh,qq{
	        update t_xfer_replica
		    set state = 0, time_state = :now
		    where $mynodes and state = 1},
		    ":now" => $now, %myargs);
	}

	my %oldcache = %{$$dbcache{FILES}};
	my $stmt = &dbprep($dbh, qq{
	    update t_xfer_replica set state = :state, time_state = :now
		where fileid = (select id from t_xfer_file where logical_name = :lfn)
		and $mynodes});
	foreach my $f (values %$files)
	{
	    next if ! defined $$f{LFN} || ! defined $$f{PFN};
	    my $isstaged = $$f{STATUS} eq 'STAGED' ? 1 : 0;
	    my $oldstaged = $$dbcache{FILES}{$$f{LFN}} ? 1 : 0;
	    $$dbcache{FILES}{$$f{LFN}} = $isstaged;
	    delete $oldcache{$$f{LFN}};
	    next if $isstaged == $oldstaged;
	    
	    &dbbindexec ($stmt, ":now" => $now, %myargs,
			 ":lfn" => $$f{LFN}, ":state" => $isstaged);
	}
	foreach my $lfn (keys %oldcache)
	{
	    delete $$dbcache{FILES}{$lfn};
	    &dbbindexec ($stmt, ":now" => $now, %myargs,
			 ":lfn" => $lfn, ":state" => 0);
	}
	$dbh->commit();
	$timing{DATABASE} = &mytimeofday();

	# Issue stage-in requests for new files in batches.  Only consider
	# recent enough files in wanted state.
	my @requests = grep (defined $$_{PFN} && $$_{STATUS} eq 'UNKNOWN',
			     values %$files);
        my $nreq = scalar @requests; 
        my $nreqdone = 0;

        do {
	    my @slice = splice (@requests, 0, $$self{MAXFILES});
	    $nreqdone = scalar @slice;
	    my @pfns = map { "$$_{PFN}" } @slice;
	    $self->Logmsg ("Executing @{$$self{STAGE_CMD}} @pfns");
	    my $rc = &runcmd (&timeout_cmd($$self{TIMEOUT}, @{$$self{STAGE_CMD}}, @pfns)); 
	    $self->Alert ("$$self{STAGE_CMD} failed: @{[&runerror($rc)]}") if ($rc);
	    
	    # Mark these files as pending now in the cache
            map { $$self{STAGE_CACHE}{$$_{PFN}} = {TIME=>time(), VALUE=>"STAGEIN"} } @slice;
        } if $nreq;
	
	$timing{REQUESTS} = &mytimeofday();
	$self->Logmsg ("timing:"
		       . " nreqqueued=$nreq"
		       . " nreqdone=$nreqdone"
		       . " purge=@{[sprintf '%.1f', $timing{PURGE} - $timing{START}]}"
		       . " status=@{[sprintf '%.1f', $timing{STATUS} - $timing{PURGE}]}"
		       . " database=@{[sprintf '%.1f', $timing{DATABASE} - $timing{STATUS}]}"
		       . " requests=@{[sprintf '%.1f', $timing{REQUESTS} - $timing{DATABASE}]}"
		       . " all=@{[sprintf '%.1f', $timing{REQUESTS} - $timing{START}]}");

	# Disconnect from the database
	$self->disconnectAgent();
    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;
}

1;
