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
    my $info = { ID => $jobname, DIR => $dir,
	         TASKS => { map { $_->{TASKID} => 1 } @batch } };
    &output("$dir/info", Dumper($info));
    &touch("$dir/live");
    $jobs->{$jobname} = $info;
    $self->clean($info, $tasks);
}

# Remove destination PFNs before transferring.  Many transfer tools
# refuse to a transfer a file over an existing one, so we do force
# remove of the destination if the user gave a delete command.
sub clean
{
    my ($self, $job, $tasks, $task, $status) = @_;
    if ($status)
    {
	# Reap finished jobs
	$tasks->{$task}{DONE_CLEAN} = 1;
    }
    else
    {
	# First time around, start deletion commands for all files,
	# but only if we have a deletion command in the first place.
	$self->{MASTER}->{pmon}->State('pre-delete','start');
	foreach $task (keys %{$job->{TASKS}})
	{
	    next if $tasks->{$task}{DONE_CLEAN};
	    do { $tasks->{$task}{DONE_CLEAN} = 1; next }
	        if ! $self->{MASTER}{DELETE_COMMAND};

	    $self->{MASTER}->addJob (
		sub { $self->clean ($job, $tasks, $task, @_) },
		{ TIMEOUT => $self->{MASTER}{TIMEOUT}, LOGPREFIX => 1 },
		@{$self->{MASTER}{DELETE_COMMAND}}, "pre",
		$tasks->{$task}{TO_PFN});
	}
    }

    # Move to next stage when we've done everything
    $self->{MASTER}->{pmon}->State('pre-delete','stop');
    $self->transferBatch ($job, $tasks)
        if ! grep (! $tasks->{$_}{DONE_CLEAN}, keys %{$job->{TASKS}});
}

sub makeTransferTask
{
    my ($self, $task) = @_;
    my ($from, $to) = @$task{"FROM_NODE_ID", "TO_NODE_ID"};
    my ($from_name, $to_name) = @$task{"FROM_NODE", "TO_NODE"};
    my @from_protos = split(/\s+/, $$task{FROM_PROTOS} || '');
    my @to_protos   = split(/\s+/, $$task{TO_PROTOS} || '');
    my $cats = $self->{CATALOGUES};

    my ($from_cat, $to_cat);
    eval
    {
        $from_cat    = &dbStorageRules($self->{MASTER}->{DBH}, $cats, $from);
        $to_cat      = &dbStorageRules($self->{MASTER}->{DBH}, $cats, $to);
    };
    do { chomp ($@); $self->Alert ("catalogue error: $@"); return; } if $@;
#   Pick out the set of allowed protocols for this agent.
    my @protocols = $self->protocols();
    foreach ( @protocols )
    {
      push @to_protos,   $_ if exists $to_cat->{$_};
      push @from_protos, $_ if exists $from_cat->{$_};
    }
    my $protocol    = undef;

    # Find matching protocol.
    foreach my $p (@to_protos)
    {
        next if ! grep($_ eq $p, @from_protos);
        $protocol = $p;
        last;
    }

    # If this is MSS->Buffer transition, pretend we have a protocol.
    $protocol = 'srm' if ! $protocol && $$task{FROM_KIND} eq 'MSS';
    
    # Check that we have prerequisite information to expand the file names.
    return if (! $from_cat
               || ! $to_cat
               || ! $protocol
               || ! $$from_cat{$protocol}
               || ! $$to_cat{$protocol});

    # Try to expand the file name. Follow destination-match instead of remote-match
# FIXME Need to add custodiality!
    $task->{FROM_PFN} = &applyStorageRules($from_cat, $protocol, $to_name, 'pre', $task->{LOGICAL_NAME}, $task->{IS_CUSTODIAL});
    $task->{TO_PFN}   = &applyStorageRules($to_cat,   $protocol, $to_name, 'pre', $task->{LOGICAL_NAME}, $task->{IS_CUSTODIAL});
}

1;
