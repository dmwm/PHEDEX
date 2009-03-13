package PHEDEX::Transfer::SRM;
use strict;
use warnings;
use base 'PHEDEX::Transfer::Command';
use PHEDEX::Core::Command;
use POE;
use Getopt::Long;

# Command back end defaulting to srmcp and supporting batch transfers.
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;
    
    # Get derived class arguments and defaults
    my $options = shift || {};
    my $params = shift || {};

    # Set my defaults where not defined by the derived class.
    $params->{PROTOCOLS}   ||= [ 'srmv2', 'srm' ];  # Accepted protocols
    $params->{COMMAND}     ||= [ 'srmcp' ];  # Transfer command
    $params->{BATCH_FILES} ||= 10;           # Max number of files per batch
    $params->{NJOBS}       ||= 30;           # Max number of parallel commands
	
    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);
    bless $self, $class;
    return $self;
}

# Transfer a batch of files.
sub start_transfer_job
{
    my ( $self, $kernel, $session, $jobid ) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];

    my $job = $self->{JOBS}->{$jobid};

    # Prepare copyjob and report names.
    my $spec = "$job->{DIR}/copyjob";
    my $report = "$job->{DIR}/srm-report";

    # Now generate copyjob
    &output ($spec, join ("", map { "$_->{FROM_PFN} ".
		                    "$_->{TO_PFN}\n" }
		          values %{$job->{TASKS}}));

    my $postback = $session->postback('wrapper_task_done');
    my $wrapper = new PHEDEX::Transfer::Wrapper ( CMD => [ @{$self->{COMMAND}}, 
							   "-copyjobfile=$spec",
							   "-report=$report" ],
						  TIMEOUT => $self->{TIMEOUT},
						  WORKDIR => $job->{DIR},
						  TASK_DONE_CALLBACK => $postback
						  );
    $job->{STARTED} = &mytimeofday();
}

1;
