package UtilsDownload; use strict; use warnings; use base 'UtilsJobManager';
use UtilsLogging;
use UtilsTiming;
use UtilsCatalogue;
use UtilsMisc;
use Getopt::Long;
use POSIX;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = (@_);

    # Parse additional options
    local @ARGV = @{$args{BACKEND_ARGS} || []};
    Getopt::Long::Configure qw(default pass_through norequire_order);
    &GetOptions ("batch-files=i"  => \$args{BATCH_FILES},
		 "batch-size=s"   => sub { $args{BATCH_SIZE} = &sizeValue($_[1]) },
		 "protocols=s"    => sub { push(@{$args{PROTOCOLS}},
						split(/,/, $_[1])) },
		 "jobs=i"         => \$args{NJOBS},
		 "timeout=i"      => \$args{TIMEOUT});

    # Initialise myself
    my $self = $class->SUPER::new(%args);
    my %params = (MASTER	=> undef,	# My owner
		  PROTOCOLS	=> undef,	# Accepted protocols
		  NJOBS		=> 5,		# Max number of parallel transfers
		  TIMEOUT	=> 3600,	# Maximum execution time
		  BATCH_FILES	=> undef,	# Max number of files per batch
		  BATCH_SIZE	=> undef,	# Max number of bytes per batch
		  BATCHID	=> 0);		# Running batch counter
    
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Start timer on a file operation
sub startFileTiming
{
    my ($self, $file, $op) = @_;
    push (@{$$file{TIMING}}, [ $op, &mytimeofday() ]);
}

# Stop timer on a file operation
sub stopFileTiming
{
    my ($self, $file) = @_;
    my $last = pop(@{$$file{TIMING}});
    push (@$last, &mytimeofday());
    push (@{$$file{TIMING}}, $last);
}

# Determine how much unused capacity we have: how many new files we
# are willing to take into transfer right now.  We keep our job queue
# at 1.5 times the theoretical maximum allowed by batch size limits.
# This is to prevent the backend job slots, the real transfers, from
# drying up if there are files available for transfer.
sub transferSlots
{
    my ($self, $files) = @_;
    my $nbatch = $$self{BATCH_FILES} || 1;
    my $inxfer = scalar grep($$_{TO_STATE} == 2, values %$files);
    my $maxjobs = ceil($nbatch * $$self{NJOBS} * 1.5);
    my $available = $maxjobs - $inxfer;
    return $available >= 0 ? $available : 0;
}

# Fill into a file transfer request which protocols we are willing
# to use for download, and which download destination we will use.
sub fillFileRequest
{
    my ($self, $file) = @_;
    $$file{TO_PROTOCOLS} = join(",", @{$$self{PROTOCOLS}});
    $$file{TO_PFN} = &pfnLookup ($$file{LOGICAL_NAME},
				 $$self{PROTOCOLS}[0],
				 $$file{TO_NODE},
				 $$self{MASTER}{STORAGEMAP});
}

# Submit files into transfer in batches desired by the backend.
sub transfer
{
    my ($self, @files) = @_;

    # Create transfer batches by adding files to a new batch until we
    # exceed number of files in the batch or batch size limit.
    my ($batch, $size) = ([], 0);
    while (1)
    {
	if (! @files
	    || (scalar @$batch
		&& (scalar @$batch >= $$self{BATCH_FILES}
		    || ($$self{BATCH_SIZE} && $size >= $$self{BATCH_SIZE}))))
	{
	    # Start moving this batch
	    $self->checkTransferBypass ($batch);

	    # Prepare for the next batch
	    $$self{BATCHID}++;
	    $batch = [];
	    $size = 0;

	    # If no more files, quit
	    last if ! @files;
	}

	# Add next file to the batch
	my $file = shift(@files);
	$$file{BATCHID} = $$self{BATCHID};
	push (@$batch, $file);
	$size += $$file{FILESIZE};
    }
}

# Check for file transfer bypass.  If a BYPASS_COMMAND is specified,
# run it for each source / destination file pair.  If the command
# outputs something, use it as the new destination path and skip the
# file transfer.  This is used to short-circuit transfers between
# "virtual" and real nodes, where the source and destination storages
# overlap but we don't know it is so.
sub checkTransferBypass
{
    my ($self, $batch, $file, $out, $job) = @_;
    if ($job)
    {
	# Reap finished jobs.  Ignore status code; all we care is if
	# the command printed out anything.
	my $output = &input ($out);
	unlink ($out);

	if ($output)
	{
	    chomp ($output);

	    # It printed out something, use this as destination
	    # and pretend the file has alread been transferred.
	    &logmsg ("transfer bypassed for $$file{LOGICAL_NAME}:"
		     . " fileid=$$file{FILEID}"
		     . " from_pfn=$$file{FROM_PFN}"
		     . " to_pfn=$$file{TO_PFN}"
		     . " new_to_pfn=$output");
	    $$file{TO_PFN} = $output;
	    $$file{DONE_PRE_CLEAN} = 1;
	    $$file{DONE_TRANSFER} = 1;
	    $$file{TRANSFER_STATUS}{STATUS} = 0;
	    $$file{TRANSFER_STATUS}{REPORT} = "transfer was bypassed";
	}

	$$file{DONE_BYPASS} = 1;
	$self->stopFileTiming ($file);
    }
    else
    {
	# First time around, start jobs for all files
	foreach my $file (@$batch)
	{
	    do { $$file{DONE_BYPASS} = 1; next }
	        if $$file{FAILURE} || ! $$self{MASTER}{BYPASS_COMMAND};

	    $self->startFileTiming ($file, "bypass");
	    my $out = "$$self{MASTER}{DROPDIR}/$$file{FILEID}.bypass";
	    my $args = "$$file{FROM_PFN} $$file{TO_PFN}";
	    $$self{MASTER}->addJob (
		sub { $self->checkTransferBypass ($batch, $file, $out, @_) },
		{ TIMEOUT => $$self{TIMEOUT} },
		"sh", "-c", "@{$$self{MASTER}{BYPASS_COMMAND}} $args > $out");
	}
    }

    # Move to next stage when we've done everything for each file.
    $self->preClean ($batch)
        if ! grep (! $$_{DONE_BYPASS}, @$batch);
}

# Remove destination PFNs before transferring.  Many transfer tools
# refuse to a transfer a file over an existing one, so we do force
# remove of the destination if the user gave a delete command.
sub preClean
{
    my ($self, $batch, $file, $job) = @_;
    if ($job)
    {
	# Reap finished jobs
	$$file{DONE_PRE_CLEAN} = 1;
	$self->stopFileTiming ($file);

	if ($$job{STATUS})
	{
	    &warn("$$job{LOGFILE} has log of failed command @{$$job{CMD}}");
	}
	else
	{
	    unlink ($$job{LOGFILE});
	}
    }
    else
    {
	# First time around, start deletion commands for all files,
	# but only if we have a deletion command in the first place.
	foreach $file (@$batch)
	{
	    next if $$file{DONE_PRE_CLEAN};
	    do { $$file{DONE_PRE_CLEAN} = 1; next }
	        if $$file{FAILURE} || ! $$self{MASTER}{DELETE_COMMAND};

	    $self->startFileTiming ($file, "preclean");
	    my $joblog = "$$self{MASTER}{DROPDIR}/$$file{FILEID}.log";
	    $$self{MASTER}->addJob (
		sub { $self->preClean ($batch, $file, @_) },
		{ TIMEOUT => $$self{TIMEOUT}, LOGFILE => $joblog },
		@{$$self{MASTER}{DELETE_COMMAND}}, "pre", $file->{TO_PFN});
	}
    }

    # Move to next stage when we've done everything
    $self->transferBatch ($batch)
        if ! grep (! $$_{DONE_PRE_CLEAN}, @$batch);
}

# Transfer batch of files.  Implementation defined, default fails.
sub transferBatch
{
    my ($self, $batch) = @_;

    # Mark everything failed if it didn't already
    foreach my $file (@$batch) {
	$$file{FAILURE} ||= "file transfer not implemented";
    }

    # Move to next stage
    $self->validateBatch ($batch);
}

# After transferring a batch, check which files were successfully
# transferred.  For batch transfers, the transfer command may fail
# but yet successfully copy some files.  On the other hand, some
# tools are actually broken enough to corrupt the file in transfer.
# Defer to an external tool to determine which files ought to be
# accepted.
sub validateBatch
{
    my ($self, $batch, $file, $job) = @_;
    if ($job)
    {
	if ($$job{STATUS})
	{
	    $$file{FAILURE} =
	        "file failed validation: $$job{STATUS}"
	        . " (transfer "
		. ($$file{TRANSFER_STATUS}{STATUS}
		   ? "failed with $$file{TRANSFER_STATUS}{REPORT}"
		   : "was successful")
	        . ")";
	    &warn("$$job{LOGFILE} has log of failed command @{$$job{CMD}}");
	}
	else
	{
	    unlink ($$job{LOGFILE});
	}
	$$file{DONE_VALIDATE} = 1;
	$self->stopFileTiming ($file);
    }
    else
    {
	# First time around start validation command for all files,
	# but only if validation was requested.  If we are not doing
	# validation, just use the status from transfer command.
	foreach $file (@$batch)
	{
	    $$file{FAILURE} = $$file{TRANSFER_STATUS}{REPORT}
	        if (! $$self{MASTER}{VALIDATE_COMMAND}
		    && $$file{TRANSFER_STATUS}{STATUS});
	    do { $$file{DONE_VALIDATE} = 1; next }
	        if $$file{FAILURE} || ! $$self{MASTER}{VALIDATE_COMMAND};

	    $self->startFileTiming ($file, "validate");
	    my $joblog = "$$self{MASTER}{DROPDIR}/$$file{FILEID}.log";
	    $$self{MASTER}->addJob (
		sub { $self->validateBatch ($batch, $file, @_) },
		{ TIMEOUT => $$self{TIMEOUT}, LOGFILE => $joblog },
		@{$$self{MASTER}{VALIDATE_COMMAND}},
		$file->{TRANSFER_STATUS}{STATUS}, $file->{TO_PFN},
		$file->{FILESIZE}, $file->{CHECKSUM});
	}
    }

    $self->postClean ($batch)
        if ! grep (! $$_{DONE_VALIDATE}, @$batch);
}

# Remove destination PFNs after failed transfers.
sub postClean
{
    my ($self, $batch, $file, $job) = @_;
    if ($job)
    {
	# Reap finished jobs
	$$file{DONE_POST_CLEAN} = 1;
	$self->stopFileTiming ($file);

	if ($$job{STATUS})
	{
	    &warn("$$job{LOGFILE} has log of failed command @{$$job{CMD}}");
	}
	else
	{
	    unlink ($$job{LOGFILE});
	}
    }
    else
    {
	# Start deletion commands for failed files, but only if we
	# have a deletion command in the first place.
	foreach $file (@$batch)
	{
	    do { $$file{DONE_POST_CLEAN} = 1; next }
	        if (! $$file{FAILURE}
		    || ! $$self{MASTER}{DELETE_COMMAND}
		    || ! $$file{MASTER}{TO_PFN});

	    $self->startFileTiming ($file, "postclean");
	    my $joblog = "$$self{MASTER}{DROPDIR}/$$file{FILEID}.log";
	    $$self{MASTER}->addJob (
		sub { $self->postClean ($batch, $file, @_) },
		{ TIMEOUT => $$self{TIMEOUT}, LOGFILE => $joblog },
		@{$$self{MASTER}{DELETE_COMMAND}}, "post", $file->{TO_PFN});
	}
    }

    # Once all done, update the database
    if (! grep (! $$_{DONE_POST_CLEAN}, @$batch))
    {
	eval { $$self{MASTER}->completeTransfer (@$batch); };
	do { chomp ($@); &alert ("database error: $@") } if $@;
    }
}

1;
