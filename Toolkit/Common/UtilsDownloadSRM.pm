package UtilsDownloadSRM; use strict; use warnings; use base 'UtilsDownload';
use UtilsLogging;
use UtilsCommand;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (COMMAND => [ 'srmcp' ]); # Transfer command
    my %args = (@_);
    map { $self->{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Transfer batch of files with a single srmcp command.
sub transferBatch
{
    my ($self, $master, $batch, $job) = @_;
    if ($job && $job->{FOR_FILES})
    {
	unlink ($job->{TEMPFILE});

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
	my @copyjob = ();
        foreach my $file (@$batch)
        {
	    do { $file->{DONE_TRANSFER} = 1; next } if $file->{FAILURE};

	    # Put this file into a transfer batch
	    my $from_pfn = $file->{FROM_PFN}; $from_pfn =~ s/^[a-z]+:/srm:/;
	    $from_pfn =~ s|srm://castorgrid.cern.ch|srm://www.cern.ch:80|; # FIXME: FNAL?
	    my $to_pfn = $file->{TO_PFN}; $to_pfn =~ s/^[a-z]+:/srm:/;
	    push (@copyjob, { FILE => $file, FROM => $from_pfn, TO => $to_pfn });
        }

	# Initiate transfer
        if (scalar @copyjob)
        {
	    my $batchid = $copyjob[0]{FILE}{BATCHID};
	    my $specfile = "$master->{DROPDIR}/copyjob.$batchid";
	    if (! &output ($specfile, join ("", map { "$_->{FROM} $_->{TO}\n" } @copyjob)))
	    {
	        &alert ("failed to create copyjob for batch $batchid");
	        $master->addJob (sub { $self->transferBatch ($master, $batch) },
		    {}, "sleep", "5");
	    }
	    else
	    {
	        $master->addJob (
		    sub { $self->transferBatch ($master, $batch, @_) },
		    { FOR_FILES => [ map { $_->{FILE} } @copyjob ],
		      TIMEOUT => $self->{TIMEOUT}, TEMPFILE => $specfile },
		    @{$self->{COMMAND}}, "-copyjobfile=$specfile");
	    }
	}
    }

    # Move to next stage if all is done.
    $self->validateBatch ($master, $batch)
        if ! grep (! $_->{DONE_TRANSFER}, @$batch);
}

1;
