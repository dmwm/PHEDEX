package UtilsDownload; use strict; use warnings; use base 'Exporter';
use UtilsLogging;
use UtilsCommand;
use UtilsWriters;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = (@_);
    my $self = {
	BATCH_FILES	=> $args{BATCH_FILES} || 1,
	BATCH_SIZE	=> $args{BATCH_SIZE} || undef,
	PFNSCRIPT	=> $args{PFNSCRIPT},
	BATCHID		=> 0
    };
    bless $self, $class;
    return $self;
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

	my $transfer = $master->startFileTransfer ($dbh, shift (@files));
	last if ! $transfer;

	$transfer->{BATCHID} = $self->{BATCHID};
	push(@$batch, $transfer);
    }
    
    if (@$batch)
    {
	# Increment batch id for the next lot
	$self->{BATCHID}++;

        # Start moving this batch if it's not empty
        $self->prepareBatchInfo ($master, $batch);

	return 1;
    }
    else
    {
	return 0;
    }
}

# Keep getting source PFNs for the source files until we've got one
# for every file in the batch.  Split into jobs per guid, respecting
# the number of workers limit.  Once we get all the PFNs, get LFNs.
# Then get destination PFNs.
sub prepareBatchInfo
{
    my ($self, $master, $batch, $job) = @_;
    my $pending = 0;
    foreach my $file (@$batch)
    {
	# Reap finished jobs
	if ($job && $job->{FOR_FILE} == $file)
        {
	    my $output = &input ($job->{OUTPUT_FILE});
	    unlink ($job->{OUTPUT_FILE});
	    chomp ($output) if defined $output;

	    if ($job->{STATUS})
	    {
	        # Command failed, record failure
	        $file->{FAILURE} = "exit code $job->{STATUS} from @{$job->{CMD}}";
	    }
	    elsif (! defined $output || $output eq '')
	    {
		# Command succeded but didn't produce any output
		$file->{FAILURE} = "no output from @{$job->{CMD}}";
	    }
	    else
	    {
		# Success, collect output file and record it into the $file
		$file->{$job->{OUTPUT_VARIABLE}} = $output;
	    }
	}

	# Stop processing this file if we have failures.
	next if $file->{FAILURE};

	# Create new jobs for remaining tasks.
	if (! exists $file->{FROM_PFN})
	{
	    my $output = "$master->{DROPDIR}/$file->{GUID}.frompfn";
	    $file->{FROM_PFN} = undef;
	    $master->addJob (
		sub { $self->prepareBatchInfo ($master, $batch, @_) },
		{ OUTPUT_FILE => $output, OUTPUT_VARIABLE => "FROM_PFN", FOR_FILE => $file },
		"sh", "-c", "POOL_OUTMSG_LEVEL=100 FClistPFN"
		. " -u '$file->{FROM_CATALOGUE}' -q \"guid='$file->{GUID}'\""
		. " | grep '$file->{FROM_HOST}' > $output");
	}

	if (! exists $file->{FROM_LFN})
	{
	    my $output = "$master->{DROPDIR}/$file->{GUID}.fromlfn";
	    $file->{FROM_LFN} = undef;
	    my $job = $master->addJob (
		sub { $self->prepareBatchInfo ($master, $batch, @_) },
		{ OUTPUT_FILE => $output, OUTPUT_VARIABLE => "FROM_LFN", FOR_FILE => $file },
		"sh", "-c", "POOL_OUTMSG_LEVEL=100 FClistLFN"
		. " -u '$file->{FROM_CATALOGUE}' -q \"guid='$file->{GUID}'\""
		. " > $output");
    	}

	if (! exists $file->{TO_PFN}
	    && $file->{FROM_PFN}
	    && $file->{FROM_LFN})
	{
	    my $pfnargs = join(" ",
		    	       "guid='$file->{GUID}'",
			       "pfn='$file->{FROM_PFN}'",
		    	       "lfn='$file->{FROM_LFN}'",
			       map { "'$_=@{[$file->{ATTRS}{$_} || '']}'" }
			       sort keys %{$file->{ATTRS}});
	    my $output = "$master->{DROPDIR}/$file->{GUID}.topfn";
	    $file->{TO_PFN} = undef;
	    $master->addJob (
		sub { $self->prepareBatchInfo ($master, $batch, @_) },
		{ OUTPUT_FILE => $output, OUTPUT_VARIABLE => "TO_PFN", FOR_FILE => $file },
		"sh", "-c", "$self->{PFNSCRIPT} $pfnargs > $output");
	}

	$pending++ if (! $file->{FROM_LFN} || ! $file->{FROM_PFN} || ! $file->{TO_PFN});
    }

    # Move to next stage when we've done everything
    $self->transferBatch ($master, $batch) if ! $pending;
}

# Transfer batch of files.  Implementation defined.  For SRM, create
# a "copyjob" file with the mappings, for globus-url-copy create as
# many batches as we can (depends on source/dest directories and
# whether source/destination file name parts match!).
sub transferBatch
{
    my ($self, $master, $batch) = @_;

    # Mark everything failed if it didn't already
    foreach my $file (@$batch) {
	$file->{FAILURE} ||= "file transfer not implemented";
    }

    # Move to next stage
    $self->updateCatalogue ($master, $batch);
}

# Update catalogue for each transferred file.  If this fails, mark the
# file (not the entire batch!) transfer failed.
sub updateCatalogue
{
    my ($self, $master, $batch, $job) = @_;
    my $pending = 0;
    my $reinvoke = 0;
    foreach my $file (@$batch)
    {
	# Reap finished jobs
	if ($job && $job->{FOR_FILE} == $file)
        {
	    $file->{DONE_CATALOGUE} = 1;
	    unlink ($job->{EXTRA_FILE}) if $job->{EXTRA_FILE};
	    $file->{FAILURE} = "exit code $job->{STATUS} from @{$job->{CMD}}"
	        if $job->{STATUS};
	}

	# Skip the rest if this file has already failed
	next if $file->{FAILURE};

	# Create new jobs if we need to.
	if (! exists $file->{DONE_CATALOGUE})
	{
	    if ($file->{FROM_CATALOGUE} ne $file->{TO_CATALOGUE})
	    {
		my $tmpcat = "$master->{DROPDIR}/$file->{GUID}.xml";
		my $xmlfrag = &genXMLCatalogue ({ GUID => $file->{GUID},
						  PFNS => [ $file->{TO_PFN} ],
						  LFNS => [ $file->{FROM_LFN} ],
						  META => $file->{ATTRS} });
		if (! &output ($tmpcat, $xmlfrag))
		{
		    # Failed to write, come back later
		    &alert ("failed to generate $tmpcat");
		    $reinvoke = 1;
		}
		else
		{
		    # Schedule full catalogue copy
		    $file->{DONE_CATALOGUE} = undef;
	            $master->addJob (
		        sub { $self->updateCatalogue ($master, $batch, @_) },
		        { FOR_FILE => $file, EXTRA_FILE => $tmpcat },
		        "FCpublish", "-d", $file->{TO_CATALOGUE},
			"-u", "file:$tmpcat");
		}
	    }
	    else
	    {
		# Schedule replica addition
		$file->{DONE_CATALOGUE} = undef;
	        $master->addJob (
		    sub { $self->updateCatalogue ($master, $batch, @_) },
		    { FOR_FILE => $file },
		    "FCaddReplica", "-u", $file->{TO_CATALOGUE},
		    "-g", $file->{GUID}, "-r", $file->{TO_PFN});
	    }
	}


	# Mark pending only if there is pending catalogue update
	# so we know whether we need to reinvoke ourselves after
	# a temporary file output failure.
	$pending++ if (exists $file->{DONE_CATALOGUE} && ! $file->{DONE_CATALOGUE});
    }

    if ($reinvoke && ! $pending)
    {
	# If we failed something and want to come back, do so.  This
	# is however required only if we are not going to come back
	# here for other reasons (= there are no pending calls).
        $master->addJob (sub { $self->updateCatalogue ($master, $batch) });
    }
    elsif (! $pending)
    {
        # If we've finished working on this batch, tell master so.
        $master->completeTransferBatch ($batch);
    }
}

1;
