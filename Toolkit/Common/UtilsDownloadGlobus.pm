package UtilsDownloadGlobus; use strict; use warnings; use base 'UtilsDownload';

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (COMMAND => [ 'globus-url-copy' ]); # Transfer command
    my %args = (@_);
    map { $self->{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Transfer batch of files.  Create as many batches as we can.  This
# depends on source/dest directories and whether source/destination
# file name parts match.
sub transferBatch
{
    my ($self, $master, $batch, $job) = @_;
    my $pending = 0;
    my %groups = ();
    foreach my $file (@$batch)
    {
	if ($job && grep ($_ eq $file, @{$job->{FOR_FILES}}))
	{
	     $file->{DONE_TRANSFER} = 1;
	     $file->{FAILURE} = "exit code $job->{STATUS} from @{$job->{CMD}}"
	         if $job->{STATUS};
	}

	next if $file->{FAILURE};

	if (! exists $file->{DONE_TRANSFER})
	{
	     $file->{DONE_TRANSFER} = undef;

	     # Put this file into a transfer group.  If the files have the
	     # same file name component at the source and destination, we
	     # can group several transfers together by destination dir.
	     # Otherwise we have to make individual transfers.
	     my $from_pfn = $file->{FROM_PFN};
	     my $to_pfn = $file->{TO_PFN};
	     $from_pfn =~ s/^[a-z]:/gsiftp:/; $to_pfn =~ s/^[a-z]:/gsiftp:/;
	     my ($from_dir, $from_file) = ($from_pfn =~ m|(.*)/([^/]+)$|);
	     my ($to_dir, $to_file) = ($to_pfn =~ m|(.*)/([^/]+)$|);

	     if ($from_file eq $to_file) {
		 push (@{$groups{$to_dir}}, { FILE => $file, PATH => $from_pfn });
	     } else {
		 push (@{$groups{$to_pfn}}, { FILE => $file, PATH => $from_pfn });
	     }
        }

	$pending++ if ! $file->{DONE_TRANSFER};
    }

    # Start transfer groups.
    foreach my $dest (keys %groups)
    {
	my @files = @{$groups{$dest}};
	$master->addJob (sub { $self->transferBatch ($master, $batch, @_) },
	                 { FOR_FILES => [ map { $_->{FILE} } @files ],
			   TIMEOUT => $self->{TIMEOUT} },
	                 @{$self->{COMMAND}}, (map { $_->{PATH} } @files), $dest);
    }

    # Move to next stage if all is done.
    $self->updateCatalogue ($master, $batch) if ! $pending;
}

1;
