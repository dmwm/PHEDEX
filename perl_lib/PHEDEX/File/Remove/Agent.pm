package PHEDEX::File::Remove::Agent;
use strict;
use warnings;
use base 'PHEDEX::Core::Agent';
use File::Path;
use Data::Dumper;
use POE;

use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::DB;
use PHEDEX::Core::JobManager;

#use Devel::Size; # XXX debug
#use PHEDEX::Monitoring::Process; # XXX debug

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);

    my %params = (DBCONFIG => undef,		# Database configuration file
	  	  NODES    => undef,		# Node names to run this agent for
		  WAITTIME => 15,               # Work cycle
		  SYNCTIME => 600 + rand(120),	# Agent DB sync time
		  CMD_RM   => undef,            # cmd to remove physical files
		  PROTOCOL => 'direct',         # File access protocol
		  CATALOGUE => {},		# TFC from TMDB
		  LIMIT => 5000,                # Max number of deletions to consider at once
		  JOBS	=> 1,			# Max parallel delete jobs
		  TIMEOUT => 30,                # Timout for deletion jobs
		  RETRY => 1,			# Retry failed attempts, forever!
		  );
    
    my %args = (@_);
    foreach ( keys %params )
    {
      $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_};
    }

    # Create a JobManager
    $self->{JOBMANAGER} = PHEDEX::Core::JobManager->new (
						NJOBS	=> $self->{JOBS},
						VERBOSE	=> $self->{VERBOSE},
						DEBUG	=> $self->{DEBUG},
							);
    
    # Handle signals
    $SIG{INT} = $SIG{TERM} = sub { $self->{SIGNALLED} = shift;
				   $self->{JOBMANAGER}->killAllJobs() };

    # Enhanced debugging! XXX
    $self->{STATISTICS_INTERVAL} = 600;
    &PHEDEX::Monitoring::Process::MonitorSize('JobManager', $self->{JOBMANAGER});
    &PHEDEX::Monitoring::Process::MonitorSize('DBH', $self->{DBH});

    bless $self, $class;
    return $self;
}

sub init
{
    my $self = shift;
    $self->SUPER::init(@_);
    
    # Remove all pending flags from the workdir
    foreach my $drop ($self->readPending()) {
	my $qfile = "$$self{WORKDIR}/$drop/queued";
	unlink $qfile if -f $qfile;
    }
}


sub _poe_init
{
    my ($self, $kernel, $session) = @_[ OBJECT, KERNEL, SESSION ];
#    $session->option(trace => 1);  $|++; # XXX Debugging

    my @poe_subs = qw( sync_deletions );
    $kernel->state($_, $self) foreach @poe_subs;

    # Get periodic events going
    $kernel->yield('sync_deletions');
}

# Pick up work from the database.
sub sync_deletions
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  $kernel->delay_set('sync_deletions', $self->{SYNCTIME});
  eval {
      my $dbh = $self->connectAgent();
      $self->expandNodes();
      my ($npending, $ndone) = $self->report_work_done();
      my $nfetched = $self->fetch_deletions($npending);
      my $ndeleted = $self->logically_delete();
      $dbh->commit();
      $self->Logmsg("synced with database: got $nfetched new files, $npending pending, $ndone finished");
      $self->disconnectAgent();
  };
  $self->rollbackOnError();
#  $self->Dbgmsg("sizeof(self)=",Devel::Size::total_size($self));
#  $self->Dbgmsg("sizeof(JobManager)=",Devel::Size::total_size($self->{JOBMANAGER}));
#  $self->Dbgmsg("sizeof(DBH)=",Devel::Size::total_size(\$self->{DBH}));
#  &output ("$$self{DROPDIR}/".++$$self{DUMPSELF}, Dumper ($self)); # XXX DEBUG
}

# Get a list of files to delete and write them to our inbox
sub fetch_deletions
{
    my ($self, $npending) = @_;
    my $dbh = $self->{DBH};
    my $limit = $self->{LIMIT};
    my $now = &mytimeofday();

    # Get the list of files from t_xfer_delete.  Take the earliest
    # deletion requests first, order by block in order to optimize
    # block retransfers
    my ($node_filter, %node_args) = $self->myNodeFilter ("xd.node");
    my $q = &dbexec($dbh,qq{
	select xd.node nodeid, n.name node, xd.time_request, 
	       xd.fileid, xf.logical_name lfn
	 from t_xfer_delete xd
	 join t_xfer_file xf on xd.fileid = xf.id
         join t_adm_node n on n.id = xd.node
	where xd.time_complete is null 
	  and $node_filter
	order by xd.time_request asc, xd.node, xf.inblock asc
    }, %node_args);

    # Prepare catalogs for LFN->PFN translation
    foreach my $node (keys %{$self->{NODES_ID}}) {
	&dbStorageRules($self->{DBH},
			$self->{CATALOGUE},
			$self->{NODES_ID}{$node});
    }

    my $new_deletions = 0;
    while (my $f = $q->fetchrow_hashref())
    {
	# Check that the file not already pending deletion
	next if -d "$$self{WORKDIR}/$$f{FILEID}";

	# Check that we're not over the limit
	if ($new_deletions + $npending >= $limit) {
	    $self->Warn("reached local queue limit ($self->{LIMIT}), not queuing more");
	    last;
	}

	# LFN -> PFN
	my $node = $f->{NODEID};
	my $lfn =  $f->{LFN};
	my ($tkn, $pfn) = &applyStorageRules($self->{CATALOGUE}{$node},
					     $self->{PROTOCOL},
					     $node,
					     'pre',
					     $lfn,
					     'n' # $IS_CUSTODIAL
					     );
	do { $self->Alert ("no pfn for $lfn, skipping"); next } if ! $pfn;

	# Augment the file object
	$f->{PFN} = $pfn;
	$f->{TIME_RECEIVE} = &mytimeofday();
	
	# Write the object to our inbox
	my $dropdir = $self->write_inbox($f);
	$new_deletions++ if $dropdir;
    }
    $q->finish();  # free resources in case we didn't use all results
    return $new_deletions;   # return the number of dropdirs we created
}

# Create a drop for deleting a file.  We create a drop for ourselves,
# i.e. in our own inbox, and then process the file in "processDrop".
# This way we have a permanent record of where we are with deleting
# the file, in case we have to give up some operation for temporary
# failures.
sub write_inbox
{
    my ($self, $file) = @_;

    # Create a pending drop in my inbox
    my $dropdir = "$$self{INBOX}/$$file{FILEID}";
    do { $self->Alert ("$dropdir already exists"); return 0; } if -d $dropdir;
    do { $self->Alert ("failed to submit $$file{FILEID}"); &rmtree ($dropdir); return 0; }
	if (! &mkpath ($dropdir)
	    || ! &output ("$dropdir/packet", Dumper ($file))
	    || ! &touch ("$dropdir/go.pending"));

    $self->Dbgmsg("created drop $dropdir for lfn=$file->{LFN}") if $self->{DEBUG};
    return $dropdir;
}

# Iterate through all drops in the inbox and logically delete them,
# then mark them as ready for processing
sub logically_delete
{
    my ($self) = @_;
    
    my $ndeleted = 0;
    foreach my $drop ($self->readInbox(1)) { # return all folders in inbox
	my $dropdir = "$$self{INBOX}/$drop";
	my $file = $self->loadPacket($drop, $self->{INBOX}) ||
	    do { $self->Alert("could not load packet in $dropdir"); next; };

	# Try to logically delete the file
	next unless $self->delete_replica($file);

	# Mark the drop ready for processing
	if (! &mv ("$dropdir/go.pending", "$dropdir/go")) {
	    $self->Alert ("failed to mark drop $dropdir ready to go, deleting it");
	    &rmtree($dropdir);
	    next;
	}
	$ndeleted++;
    }
    return $ndeleted;
}

# Delete a file.  We do one step at a time; if the step fails, we just
# tell the caller to come back here again at a more opportune time.
# The steps are ordered such that they are safe to execute several
# times if we have to give for one reason or another.
sub delete_replica
{
    my ($self, $file) = @_;
    my $status = eval {
	my $dbh = $self->connectAgent();
	my @nodes = $self->expandNodes();

	# Get Buffer Node if this is for an MSS node.  We will check
	# transfers for the buffer node along with the MSS node, and
	# delete replicas for the buffer node as well as the MSS node.
	# We will only mark the deletion done for the MSS node
	# however.
	# TODO:  Make this feature naming-convention independent
	my %node_binds = (':node1' => $$file{NODEID});
	if ($$file{NODE} =~ /_MSS$/) {
	    my $buffer = $$file{NODE};
	    $buffer =~ s/_MSS$/_Buffer/;
	    my ($buffer_id) = &dbexec($dbh, qq{ select id from t_adm_node where name = :buffer },
				      ':buffer' => $buffer)->fetchrow();
	    $node_binds{':node2'} = $buffer_id if $buffer_id;
	}
	my $node_list = join(',', keys %node_binds);
	
	# Make sure the file is still safe to delete.  More transfers
	# out might have been created for this file while we were not
	# minding this particular file (sleeping or deleting things).
	my ($nxfer) = &dbexec($dbh, qq{
	    select count(fileid) from t_xfer_task xt
 	     where xt.from_node in ($node_list)
	      and xt.fileid = :fileid },
	    %node_binds,
	    ":fileid" => $$file{FILEID})
	    ->fetchrow();

	if ($nxfer)
	{
	    $self->Warn ("not removing $$file{LFN}, $nxfer pending transfers");
	    return 0;
	}

	# Now delete the replica entry to avoid new transfer edges.
	&dbexec($dbh, qq{
	    delete from t_xfer_replica where fileid = :fileid and node in ($node_list)},
	    ":fileid" => $$file{FILEID}, %node_binds);

	return 1; # exit eval
    };
    $self->rollbackOnError();

    # Return status code to caller
    return $status;
}

sub loadPacket
{
    my ($self, $drop, $dir) = @_;
    $dir ||= $$self{WORKDIR};
    my $dropdir = "$dir/$drop";

    # Read back file information
    my $file = do { no strict "vars"; eval &input ("$dropdir/packet") };
    if ($@ || !$file || !$$file{FILEID} || !$$file{LFN} || !$$file{PFN} || !$$file{TIME_RECEIVE})
    {
	$self->Alert ("corrupt packet in $drop");
	$self->markBad ($drop);
	return undef;
    }
    return $file;
}

# Process a drop directory.  Called form PHEDEX::Core::Agent::process
# with a period of WAITTIME. Triggers the physical deletion if it hasn't already
# been queued.
sub processDrop
{
    my ($self, $drop) = @_;
    my $dropdir = "$$self{WORKDIR}/$drop";
    &timeStart($$self{STARTTIME});

    # Sanity checking
    return if (! $self->inspectDrop ($drop));
    delete $$self{BAD}{$drop};

    my $file = $self->loadPacket($drop) || 
	do { $self->Alert("could not load packet in $dropdir"); return undef; };

    # Queue deletion command, if not already queued
    if (!(-f "$dropdir/queued" || -f "$dropdir/report")) {
	$self->Dbgmsg("queuing drop $dropdir for lfn=$file->{LFN}") if $self->{DEBUG};
	my $log = "$dropdir/log";
	$self->{JOBMANAGER}->addJob( sub { $self->deleteJob ($drop, @_) },
		       { TIMEOUT => $$self{TIMEOUT}, LOGFILE => $log },
		       (@{$$self{CMD_RM}}, 'post', $$file{PFN}) );
	&touch ("$dropdir/queued");
    }
}

# Callback from JobManager job.  Handles success/failure of a deletion.
sub deleteJob
{
    my ($self, $drop, $job) = @_;
    my $dropdir = "$$self{WORKDIR}/$drop";
    unlink "$dropdir/queued";  # no longer waiting for this file
    my $success = $$job{STATUS_CODE} ? 0 : 1;
    my $file = $self->loadPacket($drop) || 
	do { $self->Alert("could not load packet in $dropdir"); return undef; };
    
    if (!$success)
    {
	$self->Warn("failed to delete file $$file{PFN} at node "
	      ."$$file{NODE}, log in $$job{LOGFILE}");
    }
    if ( $success || !$self->{RETRY} )
    {
        if ( $success )
        {
	    $self->Logmsg("deleted file $$file{PFN} at node $$file{NODE}");
	}
        if ( !$success && !$self->{RETRY} )
        {
	    $self->Warn("giving up on file $$file{PFN} at node $$file{NODE}");
	}

	$self->Dbgmsg("deletion done for drop $dropdir for lfn=$file->{LFN}") if $self->{DEBUG};
	&output("$dropdir/time-done", $$job{FINISH}) # record the completion time
	    && &touch("$dropdir/report");            # set the report-to-database flag
    }

    # Log deletion statistics
    $self->Logmsg ("dstats:",
		   " status-code=", $$job{STATUS_CODE},
		   " node=$$file{NODE}",
		   " file=$$file{FILEID}",
		   " lfn=$$file{LFN}",
		   " pfn=$$file{PFN}",
		   " t-request=$$file{TIME_REQUEST}",
		   " t-receive=$$file{TIME_RECEIVE}",
		   " t-cmdstart=$$job{START}",
		   " t-done=$$job{FINISH}",
		   " d-cmd=",   sprintf("%0.3f", $$job{FINISH} - $$job{START}),
		   " d-local=", sprintf("%0.3f", $$job{FINISH} - $$file{TIME_RECEIVE}),
		   " d-total=", sprintf("%0.3f", $$job{FINISH} - $$file{TIME_REQUEST})
		   );
}

# Iterate through completed deletions in the work directory, and
# report completed deletions to the database
sub report_work_done
{
    my ($self) = @_;
    my $ndone = 0;
    my $npending = 0;
    foreach my $drop ($self->readPending()) {
	$npending++;
	my $dropdir = "$$self{WORKDIR}/$drop";
	next unless -f "$dropdir/report"; # check for the report flag
	my $file = $self->loadPacket($drop) || 
	    do { $self->Alert("could not load packet in $dropdir"); next; };

	# Report completition time to DB
	eval {
	    my $dbh = $self->connectAgent();
	    my $time_complete = &input("$dropdir/time-done") || &mytimeofday();
	    &dbexec($dbh, qq{
		update t_xfer_delete 
		    set time_complete = :time_complete
		    where fileid = :fileid and node = :node },
		    ":fileid" => $$file{FILEID},
		    ":node" => $$file{NODEID},
		    ":time_complete" => $time_complete );
	};
	$self->rollbackOnError() && next;
	
	# We are done with this drop
	$self->Dbgmsg("deleting drop $dropdir for lfn=$file->{LFN}") if $self->{DEBUG};
	&touch ("$dropdir/done");
	$self->relayDrop ($drop);
	$ndone++;
    }
    return ($npending - $ndone, # number of pending jobs
	    $ndone);            # number done, reported
}

sub idle
{
    my ($self, @pending) = @_;
    # nothing to do
}

sub reloadConfig
{
  my ($self,$Config) = @_;
  my $config = $Config->select_agents($self->{LABEL});
  my $val;
  foreach ( qw / LIMIT VERBOSE DEBUG WAITTIME / )
  {
    next unless defined ($val = $config->{OPTIONS}{$_});
    $self->Logmsg("reloadConfig: set $_=$val");
    $self->{$_} = $val;
  }
  $val = $config->{OPTIONS}{JOBS};
  if ( defined($val) )
  {
    $self->Logmsg("reloadConfig: set NJOBS=$val in my JobManager");
    $self->{JOBMANAGER}{NJOBS} = $val;
  }
} 

1;
