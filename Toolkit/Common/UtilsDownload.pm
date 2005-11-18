package UtilsDownload; use strict; use warnings; use base 'Exporter';
use UtilsLogging;
use UtilsCommand;
use UtilsWriters;
use UtilsTiming;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = (@_);
    my $self = {
	BATCH_FILES	=> $args{BATCH_FILES} || 1,
	BATCH_SIZE	=> $args{BATCH_SIZE} || undef,
	DELETE_COMMAND	=> $args{DELETE_COMMAND} || undef,
	VALIDATE_COMMAND=> $args{VALIDATE_COMMAND} || undef,
	PFN_GEN_COMMAND	=> $args{PFN_GEN_COMMAND},
	BYPASS_COMMAND	=> $args{BYPASS_COMMAND},
	PUBLISH_COMMAND	=> $args{PUBLISH_COMMAND},
	TIMEOUT		=> $args{TIMEOUT},
	BATCHID		=> 0
    };
    bless $self, $class;
    return $self;
}

# Start timer on a file operation
sub startFileTiming
{
    my ($self, $file, $op) = @_;
    push (@{$file->{TIMING}}, [ $op, &mytimeofday() ]);
}

# Stop timer on a file operation
sub stopFileTiming
{
    my ($self, $file) = @_;
    my $last = pop(@{$file->{TIMING}});
    push (@$last, &mytimeofday());
    push (@{$file->{TIMING}}, $last);
}

# Keep adding new files to the batch until quota is reached.
sub consumeFiles
{
    my ($self, $master, $dbh) = @_;
    my ($batch, $size, @files) = ([], 0);

    # Keep adding files to the batch until we exceed the limits given
    # or there are no more files available to copy.
    while (scalar @$batch < $self->{BATCH_FILES}
	   && (! $self->{BATCH_SIZE} || $size < $self->{BATCH_SIZE}))
    {
	@files = $master->nextFiles($dbh, $self->{BATCH_FILES}) if ! @files;
	last if ! @files;

	my $file = $master->startFileTransfer ($dbh, shift (@files));
	last if ! $file;

	$size += $file->{FILESIZE};
	$file->{BATCHID} = $self->{BATCHID};
	push(@$batch, $file);
    }
    
    if (@$batch)
    {
	# Increment batch id for the next lot
	$self->{BATCHID}++;

        # Start moving this batch if it's not empty
        $self->getDestinationPaths ($master, $batch);

	return 1;
    }
    else
    {
	return 0;
    }
}

# Get destination PFNs for all files.
sub getDestinationPaths
{
    my ($self, $master, $batch, $file, $outfile, $job) = @_;
    if ($job)
    {
	# Reap finished jobs.
	my $output = &input ($outfile);
	unlink ($outfile);
	chomp ($output) if defined $output;

	$file->{DONE_TO_PFN} = 1;
	if ($job->{STATUS}) {
	    # Command failed, record failure
	    $file->{FAILURE} = "exit code $job->{STATUS} from @{$job->{CMD}}";
	} elsif (! defined $output || $output eq '') {
	    # Command succeded but didn't produce any output
	    $file->{FAILURE} = "no output from @{$job->{CMD}}";
	} else {
	    # Success, collect output file and record it into the $file
	    $file->{TO_PFN} = $output;
	}

	$self->stopFileTiming($file);
    }
    else
    {
	# First time around, start jobs for all files
	foreach my $file (@$batch)
	{
	    do { $file->{DONE_TO_PFN} = 1; next } if $file->{FAILURE};

	    $self->startFileTiming ($file, "pfndest");
	    my $outfile = "$master->{DROPDIR}/$file->{GUID}.topfn";
	    my $args = join(" ",
		    	    "guid='$file->{GUID}'",
			    "pfn='$file->{FROM_PFN}'",
			    "pfntype='$file->{PFNTYPE}'",
		    	    "lfn='$file->{LFN}'",
			    map { "'$_=@{[$file->{ATTRS}{$_} || '']}'" }
			    sort keys %{$file->{ATTRS}});
	    $master->addJob (
		sub { $self->getDestinationPaths ($master, $batch, $file, $outfile, @_) },
		{ TIMEOUT => $self->{TIMEOUT} },
		"sh", "-c", "@{$self->{PFN_GEN_COMMAND}} $args > $outfile");
	}
    }

    # Move to next stage when we've done everything for each file.
    $self->getBypassPaths ($master, $batch)
        if ! grep (! $_->{DONE_TO_PFN}, @$batch);
}

# Check for file transfer bypass.  If a BYPASS_COMMAND is specified,
# run it for each source / destination file pair.  If the command
# outputs something, use it as the new destination path and skip the
# file transfer.  This is used to short-circuit transfers between
# "virtual" and real nodes, where the source and destination storages
# overlap but we don't know it is so.
sub getBypassPaths
{
    my ($self, $master, $batch, $file, $outfile, $job) = @_;
    if ($job)
    {
	# Reap finished jobs.  Ignore status code; all we care is if
	# the command printed out anything.
	my $output = &input ($outfile);
	unlink ($outfile);
	chomp ($output) if defined $output;

	$file->{DONE_BYPASS} = 1;
	if ($output)
	{
	    # It print outed something, use this as destination
	    # and pretend the file has alread been transferred.
	    &logmsg ("transfer bypassed for $file->{GUID}:"
		     . " from=$file->{FROM_PFN}"
		     . " to=$file->{TO_PFN}"
		     . " newto=$output");
	    $file->{TO_PFN} = $output;
	    $file->{DONE_PRE_CLEAN} = 1;
	    $file->{DONE_TRANSFER} = 1;
	    $file->{TRANSFER_STATUS}{STATUS} = 0;
	    $file->{TRANSFER_STATUS}{REPORT} = "transfer was bypassed";
	}

	$self->stopFileTiming ($file);
    }
    else
    {
	# First time around, start jobs for all files
	foreach my $file (@$batch)
	{
	    do { $file->{DONE_BYPASS} = 1; next }
	        if $file->{FAILURE} || ! $self->{BYPASS_COMMAND};

	    $self->startFileTiming ($file, "bypass");
	    my $outfile = "$master->{DROPDIR}/$file->{GUID}.bypass";
	    my $args = "$file->{FROM_PFN} $file->{TO_PFN}";
	    $master->addJob (
		sub { $self->getBypassPaths ($master, $batch, $file, $outfile, @_) },
		{ TIMEOUT => $self->{TIMEOUT} },
		"sh", "-c", "@{$self->{BYPASS_COMMAND}} $args > $outfile");
	}
    }

    # Move to next stage when we've done everything for each file.
    $self->preClean ($master, $batch)
        if ! grep (! $_->{DONE_BYPASS}, @$batch);
}

# Remove destination PFNs before transferring.  Many transfer tools
# refuse to a transfer a file over an existing one, so we do force
# remove of the destination if the user gave a delete command.
sub preClean
{
    my ($self, $master, $batch, $file, $job) = @_;
    if ($job)
    {
	# Reap finished jobs.  We don't care about success here.
	$file->{DONE_PRE_CLEAN} = 1;
	$self->stopFileTiming ($file);
    }
    else
    {
	# First time around, start deletion commands for all files,
	# but only if we have a deletion command in the first place.
	foreach $file (@$batch)
	{
	    next if $file->{DONE_PRE_CLEAN};
	    do { $file->{DONE_PRE_CLEAN} = 1; next }
	        if $file->{FAILURE} || ! $self->{DELETE_COMMAND};

	    $self->startFileTiming ($file, "preclean");
	    $master->addJob (
		sub { $self->preClean ($master, $batch, $file, @_) },
		{ TIMEOUT => $self->{TIMEOUT} },
		@{$self->{DELETE_COMMAND}}, "pre", $file->{TO_PFN});
	}
    }

    # Move to next stage when we've done everything
    $self->transferBatch ($master, $batch)
        if ! grep (! $_->{DONE_PRE_CLEAN}, @$batch);
}

# Transfer batch of files.  Implementation defined, default fails.
sub transferBatch
{
    my ($self, $master, $batch) = @_;

    # Mark everything failed if it didn't already
    foreach my $file (@$batch) {
	$file->{FAILURE} ||= "file transfer not implemented";
    }

    # Move to next stage
    $self->validateBatch ($master, $batch);
}

# After transferring a batch, check which files were successfully
# transferred.  For batch transfers, the transfer command may fail
# but yet successfully copy some files.  On the other hand, some
# tools are actually broken enough to corrupt the file in transfer.
# Defer to an external tool to determine which files ought to be
# accepted.
sub validateBatch
{
    my ($self, $master, $batch, $file, $job) = @_;
    if ($job)
    {
	$file->{DONE_VALIDATE} = 1;
	if ($job->{STATUS})
	{
	    $file->{FAILURE} =
	        "file failed validation: $job->{STATUS}"
	        . " (transfer "
		. ($file->{TRANSFER_STATUS}{STATUS}
		   ? "failed with $file->{TRANSFER_STATUS}{REPORT}"
		   : "was successful")
	        . ")";
	}

	$self->stopFileTiming ($file);
    }
    else
    {
	# First time around start validation command for all files,
	# but only if validation was requested.  If we are not doing
	# validation, just use the status from transfer command.
	foreach $file (@$batch)
	{
	    do { $file->{FAILURE} = $file->{TRANSFER_STATUS}{REPORT} }
	        if ! $self->{VALIDATE_COMMAND} && $file->{TRANSFER_STATUS}{STATUS};
	    do { $file->{DONE_VALIDATE} = 1; next }
	        if $file->{FAILURE} || ! $self->{VALIDATE_COMMAND};

	    $self->startFileTiming ($file, "validate");
	    $master->addJob (
		sub { $self->validateBatch ($master, $batch, $file, @_) },
		{ TIMEOUT => $self->{TIMEOUT} },
		@{$self->{VALIDATE_COMMAND}},
		$file->{TRANSFER_STATUS}{STATUS}, $file->{TO_PFN},
		$file->{FILESIZE}, $file->{CHECKSUM});
	}
    }

    $self->updateCatalogue ($master, $batch)
        if ! grep (! $_->{DONE_VALIDATE}, @$batch);
}

# Update catalogue for successfully transferred files.
sub updateCatalogue
{
    my ($self, $master, $batch, $file, $extra, $job) = @_;
    if ($job)
    {
	# Reap finished jobs
	$file->{DONE_CATALOGUE} = 1;
	unlink (@$extra);
	$file->{FAILURE} = "exit code $job->{STATUS} from @{$job->{CMD}}"
	    if $job->{STATUS};
	$self->stopFileTiming ($file);
    }
    else
    {
	# First time around register into catalogue all successfully
	# transferred files.  However we may invoke ourselves several
	# times if we fail to generate temporary files, so protect
	# against handling each file more than once.
	foreach $file (@$batch)
	{
	    do { $file->{DONE_CATALOGUE} = 1; next } if $file->{FAILURE};
	    next if exists $file->{DONE_CATALOGUE};

	    $self->startFileTiming ($file, "publish");
	    my $tmpcat = "$master->{DROPDIR}/$file->{GUID}.xml";
	    my $xmlfrag = &genXMLCatalogue ({ GUID => $file->{GUID},
					      PFN => [ { TYPE => $file->{PFNTYPE},
							 PFN => $file->{TO_PFN} } ],
					      LFN => [ $file->{LFN} ],
					      META => $file->{ATTRS} });

	    do { &alert ("failed to generate $tmpcat"); next }
		if ! &output ($tmpcat, $xmlfrag);

	    # Schedule catalogue copy
	    $file->{DONE_CATALOGUE} = undef;
	    $master->addJob (
		sub { $self->updateCatalogue ($master, $batch, $file, [ $tmpcat, "$tmpcat.BAK" ], @_) },
		{ TIMEOUT => $self->{TIMEOUT} },
		@{$self->{PUBLISH_COMMAND}}, $file->{GUID}, $file->{TO_PFN}, $tmpcat);
	}
    }

    # If all is done, move to next stage.  Otherwise, if there are no
    # more programs being executed, we failed to create some temporary
    # files and need to invoke ourselves again a bit later.
    if (scalar (grep ($_->{DONE_CATALOGUE}, @$batch)) == scalar @$batch)
    {
	$self->postClean ($master, $batch);
    }
    elsif (! grep (exists $_->{DONE_CATALOGUE} && ! $_->{DONE_CATALOGUE}, @$batch))
    {
	$master->addJob (sub { $self->updateCatalogue ($master, $batch) },
	    {}, "sleep", "5");
    }
}

# Remove destination PFNs after failed transfers.
sub postClean
{
    my ($self, $master, $batch, $file, $job) = @_;
    if ($job)
    {
	# Reap finished jobs.  We don't care about success here.
	$file->{DONE_POST_CLEAN} = 1;
	$self->stopFileTiming ($file);
    }
    else
    {
	# Start deletion commands for failed files, but only if we
	# have a deletion command in the first place.
	foreach $file (@$batch)
	{
	    do { $file->{DONE_POST_CLEAN} = 1; next }
	        if (! $file->{FAILURE}
		    || ! $self->{DELETE_COMMAND}
		    || ! $file->{TO_PFN});

	    $self->startFileTiming ($file, "postclean");
	    $master->addJob (
		sub { $self->postClean ($master, $batch, $file, @_) },
		{ TIMEOUT => $self->{TIMEOUT} },
		@{$self->{DELETE_COMMAND}}, "post", $file->{TO_PFN});
	}
    }

    # Move to next stage when we've done everything
    $master->completeTransferBatch ($batch)
        if ! grep (! $_->{DONE_POST_CLEAN}, @$batch);
}

1;
