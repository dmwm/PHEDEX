package UtilsDownloadDCCP; use strict; use warnings; use base 'UtilsDownload';
use UtilsLogging;

#CJR this module is basically a copy of the UtilsDownloadGlobus package with modifications on
#src_pnf and dest_pfn to match requirements for a dccp. I also prevents batch transfers, since
#dccp doesn't support those.

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (COMMAND => [ 'dccp' ]); # Transfer command
    my %args = (@_);
    map { $self->{$_} = $args{$_} || $params{$_} } keys %params;

    # Only file per transfer supported.
    if ($self->{BATCH_FILES} > 1)
    {
	&logmsg ("transfer batching not supported, forcing batch mode off");
	$self->{BATCH_FILES} = 1;
    }

    bless $self, $class;
    return $self;
}

# Transfer batch of files.  Create as many batches as we can.  This
# depends on source/dest directories and whether source/destination
# file name parts match.
sub transferBatch
{
    my ($self, $master, $batch, $job) = @_;
    if ($job)
    {
	# Reap finished jobs
	foreach my $file (@{$job->{FOR_FILES}})
	{
	    $file->{DONE_TRANSFER} = 1;
	    $file->{TRANSFER_STATUS}{STATUS} = $job->{STATUS};
	    $file->{TRANSFER_STATUS}{REPORT}
	        = "exit code $job->{STATUS} from @{$job->{CMD}}";
	}
    }
    else
    {
	# First time around initiate transfers all files.
        my %groups = ();
        foreach my $file (@$batch)
        {
	    do { $file->{DONE_TRANSFER} = 1; next } if $file->{FAILURE};

	    # Put this file into a transfer group.  If the files have the
	    # same file name component at the source and destination, we
	    # can group several transfers together by destination dir.
	    # Otherwise we have to make individual transfers.
	    # (Remove protocol, host part and collapse double slashes.)
	    my ($from_pfn, $to_pfn) = ($file->{FROM_PFN}, $file->{TO_PFN});
	    $from_pfn =~ s/^[a-z]+://; $to_pfn =~ s/^[a-z]+://;
	    $from_pfn =~ s|^//[^/]+//|/|; $to_pfn =~ s|^//[^/]+//|/|;
	    $from_pfn =~ s|//|/|g; $to_pfn =~ s|//|/|g;
	    my ($from_dir, $from_file) = ($from_pfn =~ m|(.*)/([^/]+)$|);
	    my ($to_dir, $to_file) = ($to_pfn =~ m|(.*)/([^/]+)$|);

	    # If destination LFNs are equal and we attempt batch transfers,
	    # try to create optimal transfer groups.  Otherwise don't bother;
	    # if batch transfers are off, underlying globus-url-copy might
	    # not even support directories as destinations.
	    if ($from_file eq $to_file && $self->{BATCH_FILES} > 1) {
		push (@{$groups{$to_dir}}, { FILE => $file, PATH => $from_pfn });
	    } else {
		push (@{$groups{$to_pfn}}, { FILE => $file, PATH => $from_pfn });
	    }
        }

        # Now start transfer groups.
        foreach my $dest (keys %groups)
        {
	    my @files = @{$groups{$dest}};
	    $master->addJob (
		sub { $self->transferBatch ($master, $batch, @_) },
	        { FOR_FILES => [ map { $_->{FILE} } @files ],
		  TIMEOUT => $self->{TIMEOUT} },
	        @{$self->{COMMAND}}, (map { $_->{PATH} } @files), $dest);
        }
    }

    # Move to next stage if all is done.
    $self->validateBatch ($master, $batch)
        if ! grep (! $_->{DONE_TRANSFER}, @$batch);
}

1;
