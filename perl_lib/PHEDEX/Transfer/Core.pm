package PHEDEX::Transfer::Core;
use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use PHEDEX::Core::JobManager;
use PHEDEX::Core::Command;
use PHEDEX::Core::Catalogue;
use Getopt::Long;
use File::Path qw(mkpath);
use Data::Dumper;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;

    # Get derived class arguments and defaults
    my $options = shift || {};
    my $params = shift || {};

    # Set my defaults where not defined by the derived class.
    $params->{PROTOCOLS}   ||= undef;        # Transfer command
    $params->{NJOBS}       ||= 0;            # Max number of parallel transfers.  0 for infinite.
    $params->{BATCH_FILES} ||= 1;            # Max number of files per batch
    $params->{CATALOGUES} = {};

    # Set argument parsing at this level.
    $$options{'protocols=s'} = sub { $$params{PROTOCOLS} = [ split(/,/, $_[1]) ]};
    $$options{'jobs=i'} = \$$params{NJOBS};

    # Parse additional options
    local @ARGV = @{$master->{BACKEND_ARGS}};
    Getopt::Long::Configure qw(default);
    &GetOptions (%$options);

    # Initialise myself
    my $self = $class->SUPER::new();
    $self->{$_} = $params->{$_} for keys %$params;
    bless $self, $class;

    # Create a JobManager
    $self->{JOBMANAGER} = PHEDEX::Core::JobManager->new (
						NJOBS	=> $self->{NJOBS},
						VERBOSE	=> $self->{VERBOSE},
						DEBUG	=> $self->{DEBUG},
							);
    # Remember various useful details.
    $self->{MASTER} = $master;  # My owner
    $self->{VERBOSE} = $master->{VERBOSE} || 0;
    $self->{DEBUG} = $master->{DEBUG} || 0;
    $self->{BOOTTIME} = time(); # "Boot" time for this agent
    $self->{BATCHID} = 0;       # Running batch counter
    $self->{WORKDIR} = $master->{WORKDIR}; # Where job state/logs are saved

    # Locate the transfer wrapper script.
    $self->{WRAPPER} = $INC{"PHEDEX/Transfer/Core.pm"};
    $self->{WRAPPER} =~ s|/PHEDEX/Transfer/Core\.pm$|/../Toolkit/Transfer/TransferWrapper|;
    -x "$self->{WRAPPER}"
        || die "Failed to locate transfer wrapper, tried $$self{WRAPPER}\n";

    return $self;
}

# Check whether a job is alive.  By default do nothing.
sub check
{
    # my ($self, $jobname, $job, $tasks) = @_;
}

# Stop the backend.  We abandon all jobs always.
sub stop
{
    # my ($self) = @_;
}

# Check if the backend is busy.  By default, true if the number of
# currently set up copy jobs is equal or exceeds the number of jobs
# the back end can run concurrently.
sub isBusy
{
    my ($self, $to_node, $from_node) = @_;
    return $self->{JOBMANAGER}->jobsRemaining() >= $self->{NJOBS};
}

# Return the list of protocols supported by this backend.
sub protocols
{
    my ($self) = @_;
    return @{$self->{PROTOCOLS}};
}

# Start off a copy job.  Nips off "BATCH_FILES" tasks to go ahead.
sub startBatch
{
    my ($self, $list) = @_;

    my @batch = splice(@$list, 0, $self->{BATCH_FILES});
    return undef if !@batch;

    my $id = $$self{BATCH_ID}++;
    my $jobid = "job.$$self{BOOTTIME}.$id";
    my $jobdir = "$$self{WORKDIR}/$jobid";
    &mkpath($jobdir);
    my $jobinfo = { ID => $jobid, DIR => $jobdir,
		    TASKS => { map { $_->{TASKID} => $_ } @batch } };
    &output("$jobdir/info", Dumper($jobinfo));
    $self->{JOBS}->{$jobid} = $jobinfo;

    return ($jobid, $jobdir, $jobinfo->{TASKS});
}

1;
