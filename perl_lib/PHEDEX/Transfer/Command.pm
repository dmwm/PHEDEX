package PHEDEX::Transfer::Command;
use strict;
use warnings;
use base 'PHEDEX::Transfer::Core';
use PHEDEX::Transfer::Wrapper;
use POE;
use Getopt::Long;

# General transfer back end for making file copies with a simple
# command taking one pair of source and destination file names.
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;

    # Get derived class arguments and defaults
    my $options = shift || {};
    my $params = shift || {};

	# Set my defaults where not defined by the derived class.
	$params->{COMMAND}     ||= undef;        # Transfer command
	$params->{NJOBS}       ||= 1;            # Max number of parallel transfers
	$params->{BATCH_FILES} ||= 1;            # Max number of files per batch
	$params->{TIMEOUT}     ||= 3600;         # Maximum execution time
	
	# Set argument parsing at this level.
	$options->{'command=s'} = sub { $params->{COMMAND} = [ split(/,/, $_[1]) ] };
	$options->{'jobs=i'}    = \$params->{NJOBS};
	$options->{'timeout=i'} = \$params->{TIMEOUT};

    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);
    bless $self, $class;
    return $self;
}

sub setup_callbacks
{
    my ($self, $kernel, $session) = @_;
    $kernel->state('wrapper_task_done', $self);
}

sub start_transfer_job
{
    my ( $self, $kernel, $session, $jobid ) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];

    my $job = $self->{JOBS}->{$jobid};

    foreach my $task (values %{$job->{TASKS}})
    {
	my $postback = $session->postback('wrapper_task_done', $task->{TASKID});
	my $wrapper = new PHEDEX::Transfer::Wrapper ( CMD => [ @{$self->{COMMAND}}, 
							       $task->{FROM_PFN},
							       $task->{TO_PFN} ],
						      TIMEOUT => $self->{TIMEOUT},
						      WORKDIR => $job->{DIR},
						      TASK_DONE_CALLBACK => $postback
						      );
    }
}

sub wrapper_task_done
{
    my ($self, $kernel, $context, $args) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
    my ($taskid) = @$context;
    my ($xferinfo) = @$args;
    $kernel->yield('transfer_done', $taskid, $xferinfo);

}

1;
