package UtilsDownload; use strict; use warnings; use base 'UtilsJobManager';
use UtilsLogging;
use UtilsTiming;
use UtilsCatalogue;
use UtilsMisc;
use Getopt::Long;
use File::Path;
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
		  NJOBS		=> 30,		# Max number of parallel transfers
		  TIMEOUT	=> 3600,	# Maximum execution time
		  BATCH_FILES	=> undef,	# Max number of files per batch
		  BATCH_SIZE	=> undef,	# Max number of bytes per batch
		  BOOTTIME      => time(),	# "Boot" time for this agent
		  BATCHID	=> 0);		# Running batch counter
    
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Check whether a job is alive.  By default do nothing.
sub check
{
    my ($self, $jobname, $job, $tasks) = @_;
}

# Stop the backend.  We abandon all jobs always.
sub stop
{
    my ($self) = @_;
}

# Check if the backend is busy.  By default, never.
sub isBusy
{
    my ($self) = @_;
    return 0;
}

# Return the list of protocols supported by this backend.
sub protocols
{
    my ($self) = @_;
    return @{$$self{PROTOCOLS}};
}

sub startBatch
{
    my ($self, $jobs, $tasks, $list) = @_;
    &alert(ref($self) . "::startBatch not implemented");
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
	    $$self{MASTER}->addJob (
		sub { $self->preClean ($batch, $file, @_) },
		{ TIMEOUT => $$self{TIMEOUT}, LOGPREFIX => 1 },
		@{$$self{MASTER}{DELETE_COMMAND}}, "pre", $$file{TO_PFN});
	}
    }

    # Move to next stage when we've done everything
    $self->transferBatch ($batch)
        if ! grep (! $$_{DONE_PRE_CLEAN}, @$batch);
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
		    || ! $$file{TO_PFN});

	    $self->startFileTiming ($file, "postclean");
	    my $joblog = "$$self{MASTER}{DROPDIR}/$$file{FILEID}.log";
	    $$self{MASTER}->addJob (
		sub { $self->postClean ($batch, $file, @_) },
		{ TIMEOUT => $$self{TIMEOUT}, LOGPREFIX => 1 },
		@{$$self{MASTER}{DELETE_COMMAND}}, "post", $$file{TO_PFN});
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
