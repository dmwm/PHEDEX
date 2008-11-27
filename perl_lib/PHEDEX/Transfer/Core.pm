package PHEDEX::Transfer::Core;
use strict;
use warnings;
use base 'PHEDEX::Core::JobManager', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Command;
use PHEDEX::Core::Catalogue;
use Getopt::Long;
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

    # Remember various useful details.
    $self->{MASTER} = $master;  # My owner
    $self->{VERBOSE} = $master->{VERBOSE} || 0;
    $self->{DEBUG} = $master->{DEBUG} || 0;
    $self->{BOOTTIME} = time(); # "Boot" time for this agent
    $self->{BATCHID} = 0;       # Running batch counter

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
    my ($self, $jobs, $tasks) = @_;
    return scalar(keys %$jobs) >= $self->{NJOBS};
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
    my ($self, $jobs, $tasks, $dir, $jobname, $list) = @_;
    my @batch = splice(@$list, 0, $self->{BATCH_FILES});
    my $job = { ID => $jobname, DIR => $dir,
	         TASKS => { map { $_->{TASKID} => 1 } @batch } };
    &output("$dir/info", Dumper($job));
    &touch("$dir/live");
    $jobs->{$jobname} = $job;
    $self->transferBatch ($job, $tasks);
}



1;
