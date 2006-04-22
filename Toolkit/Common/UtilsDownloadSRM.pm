package UtilsDownloadSRM; use strict; use warnings; use base 'UtilsDownload';
use UtilsLogging;
use Getopt::Long;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = (@_);

    # Parse backend-specific additional options
    local @ARGV = @{$args{BACKEND_ARGS}};
    Getopt::Long::Configure qw(default pass_through require_order);
    &GetOptions ("command=s" => sub { push(@{$args{COMMAND}},
					   split(/,/, $_[1])) });

    # Initialise myself
    my $self = $class->SUPER::new(%args);
    my %params = (COMMAND	=> [ "srmcp" ]); # Transfer command
    my %default= (PROTOCOLS	=> [ "srm" ],	# Accepted protocols
		  BATCH_FILES	=> 10,		# Max number of files per batch
		  BATCH_SIZE	=> 25*1024**3);	# Max number of bytes per batch

    $$self{$_} = $args{$_} || $params{$_} || $$self{$_} || $default{$_}
	for keys %params, keys %default;

    bless $self, $class;
    return $self;
}

# Transfer a batch of files.
sub transferBatch
{
    my ($self, $batch, $files, $reportfile, $specfile, $job) = @_;
    if ($job)
    {
	# If we have a report file, build {FROM}{TO}=STATUS hash of
	# the "FROM TO STATUS" lines in the report.  Then nuke temps.
	my %reported = ();
	foreach (split (/\n/, &input($reportfile) || ''))
	{
	    my ($from, $to, $status, @rest) = split(/\s+/);
	    $reported{$from}{$to} = $status;
	}
	unlink ($specfile, $reportfile);

	# Reap finished jobs
	foreach my $file (@$files)
	{
	    $$file{DONE_TRANSFER} = 1;
	    if (exists $reported{$$file{FROM_PFN}}{$$file{TO_PFN}})
	    {
		# This copy has a report entry.  Use that instead.
		my $status = $reported{$$file{FROM_PFN}}{$$file{TO_PFN}};
		$$file{TRANSFER_STATUS}{STATUS} = $status;
	        $$file{TRANSFER_STATUS}{REPORT}
	            = "transfer report code $status;"
		      . " exit code $$job{STATUS} from @{$$job{CMD}}";
	    }
	    else
	    {
		# No report entry, use command exit code.
	        $$file{TRANSFER_STATUS}{STATUS} = $$job{STATUS};
	        $$file{TRANSFER_STATUS}{REPORT}
	            = "exit code $$job{STATUS} from @{$$job{CMD}}";
	    }
	    $self->stopFileTiming ($file);
	}
    }
    else
    {
	# First time around initiate transfers all files.  The transfers
	# jobs must be partitioned by source host such that each job has
	# only transfers from a single host.
	my %jobs = ();
        foreach my $file (@$batch)
        {
	    next if $$file{DONE_TRANSFER};
	    do { $$file{DONE_TRANSFER} = 1; next } if $$file{FAILURE};
	    $self->startFileTiming ($file, "transfer");
	    my ($host) = ($$file{FROM_PFN} =~ m|^[a-z]+://([^/:]+)|);
	    push (@{$jobs{$host}}, $file);
        }

	# Initiate transfer
        while (my ($host, $job) = each %jobs)
        {
	    # Prepare copyjob and report names.
	    my $batchid = $$job[0]{BATCHID} . "." . $host;
	    $specfile = "$$self{MASTER}{DROPDIR}/$batchid.copyjob";
	    $reportfile = "$$self{MASTER}{DROPDIR}/$batchid.report";
	    my $spec = join ("", map { "$$_{FROM_PFN} $$_{TO_PFN}\n" } @$job);

	    # Now generate copyjob
	    if (! &output ($specfile, $spec))
	    {
		foreach my $file (@$job)
		{
		    $$file{FAILURE} = "failed to create copyjob for batch $batchid: $!";
		    $$file{DONE_TRANSFER} = 1;
		}
		next;
	    }

	    $self->addJob (
		sub { $self->transferBatch
			  ($batch, $job, $reportfile, $specfile, @_) },
		    { TIMEOUT => $$self{TIMEOUT} },
		    @{$$self{COMMAND}},
		    "-copyjobfile=$specfile",
		    "-report=$reportfile");
	}
    }

    # Move to next stage if all is done.
    $self->validateBatch ($batch)
        if ! grep (! $$_{DONE_TRANSFER}, @$batch);
}

1;
