package UtilsDownloadSRM; use strict; use warnings; use base 'UtilsDownload';
use UtilsLogging;
use UtilsCommand;
use UtilsTiming;

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
	    $file->{TIMING}{FINISH} = &mytimeofday();
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
	    $file->{TIMING}{START} = &mytimeofday();

	    # Put this file into a transfer batch
	    push (@copyjob, $file);
        }

	# Initiate transfer
        if (scalar @copyjob)
        {
	    my $batchid = $copyjob[0]{BATCHID};
	    my $specfile = "$master->{DROPDIR}/copyjob.$batchid";
	    if (! &output ($specfile, join ("", map { "$_->{FROM_PFN} $_->{TO_PFN}\n" } @copyjob)))
	    {
	        &alert ("failed to create copyjob for batch $batchid");
	        $master->addJob (sub { $self->transferBatch ($master, $batch) },
		    {}, "sleep", "5");
	    }
	    else
	    {
	        $master->addJob (
		    sub { $self->transferBatch ($master, $batch, @_) },
		    { FOR_FILES => [ @copyjob ],
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
