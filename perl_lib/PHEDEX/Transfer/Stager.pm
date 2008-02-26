package PHEDEX::Transfer::Stager; use strict; use warnings; use base 'PHEDEX::Transfer::Command';
use PHEDEX::Core::Command;
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
	$$params{PROTOCOLS}   ||= [ 'direct' ];      # Accepted protocols
	$$params{COMMAND}     ||= [ 'stagercp' ];    # Transfer command
	$$params{BATCH_FILES} ||= 1;                 # Default number of files per batch
	$$params{NJOBS}       ||= 100;               # Default number of parallel transfers
	
	# Set argument parsing at this level.
	$$options{'batch-files=i'} = \$$params{BATCH_FILES};

    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);
    bless $self, $class;
    return $self;
}

# Transfer a batch of files.
sub transferBatch
{
    my ($self, $job, $tasks) = @_;

    # Prepare copyjob and report names.
    my $spec = "$$job{DIR}/copyjob";
    my $report = "$$job{DIR}/stager-report";

    # Now generate copyjob
    &output ($spec, join ("", map { "$$tasks{$_}{TO_PFN}\n" }
		          keys %{$$job{TASKS}}));

    # Fork off the transfer wrapper
    $self->addJob(undef, { DETACHED => 1 },
		  $$self{WRAPPER}, $$job{DIR}, $$self{TIMEOUT},
		  @{$$self{COMMAND}}, "-copyjobfile=$spec", "-report=$report");
}

1;
