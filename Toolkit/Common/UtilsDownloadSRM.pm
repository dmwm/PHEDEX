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
    my ($self, $master, $batch, $files, $reportfile, $specfile, $job) = @_;
    if ($job)
    {
	# If we have a report file, build {FROM}{TO}=STATUS hash of
	# the "FROM TO STATUS" lines in the report.  Then nuke temps.
	my %reported = ();
	map { my ($from, $to, $status, @rest) = split(/\s+/, $_);
	      $reported{$from}{$to} = $status }
	   split (/\n/, &input($reportfile) || '');

	unlink ($specfile, $reportfile);

	# Reap finished jobs
	foreach my $file (@$files)
	{
	    $file->{DONE_TRANSFER} = 1;
	    if (exists $reported{$file->{FROM_PFN}}{$file->{TO_PFN}}) {
		# This copy has a report entry.  Use that instead.
		my $status = $reported{$file->{FROM_PFN}}{$file->{TO_PFN}};
		$file->{TRANSFER_STATUS}{STATUS} = $status;
	        $file->{TRANSFER_STATUS}{REPORT}
	            = "transfer report code $status;"
		      . " exit code $job->{STATUS} from @{$job->{CMD}}";
	    } else {
		# No report entry, use command exit code.
	        $file->{TRANSFER_STATUS}{STATUS} = $job->{STATUS};
	        $file->{TRANSFER_STATUS}{REPORT}
	            = "exit code $job->{STATUS} from @{$job->{CMD}}";
	    }
	    $self->stopFileTiming ($file);
	}
    }
    else
    {
	# First time around initiate transfers all files.
	my @copyjob = ();
        foreach my $file (@$batch)
        {
	    next if $file->{DONE_TRANSFER};
	    do { $file->{DONE_TRANSFER} = 1; next } if $file->{FAILURE};
	    $self->startFileTiming ($file, "transfer");

	    # Put this file into a transfer batch
	    push (@copyjob, $file);
        }

	# Initiate transfer
        if (scalar @copyjob)
        {
	    my $batchid = $copyjob[0]{BATCHID};
	    $specfile = "$master->{DROPDIR}/copyjob.$batchid";
	    $reportfile = "$master->{DROPDIR}/report.$batchid";
	    if (! &output ($specfile, join ("", map { "$_->{FROM_PFN} $_->{TO_PFN}\n" } @copyjob)))
	    {
	        &alert ("failed to create copyjob for batch $batchid");
	        $master->addJob (sub { $self->transferBatch ($master, $batch) },
		    {}, "sleep", "5");
	    }
	    else
	    {
	        $master->addJob (
		    sub { $self->transferBatch ($master, $batch, \@copyjob,
				    	        $reportfile, $specfile, @_) },
		    { TIMEOUT => $self->{TIMEOUT} },
		    @{$self->{COMMAND}}, "-copyjobfile=$specfile",
		    "-report=$reportfile"));
	    }
	}
    }

    # Move to next stage if all is done.
    $self->validateBatch ($master, $batch)
        if ! grep (! $_->{DONE_TRANSFER}, @$batch);
}

1;
