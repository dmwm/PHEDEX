package UtilsDownloadSRM; use strict; use warnings; use base 'UtilsDownloadCommand';
use UtilsCommand;
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
	$$params{PROTOCOLS}   ||= [ 'srm' ];    # Accepted protocols
	$$params{COMMAND}     ||= [ 'srmcp' ];  # Transfer command
	$$params{BATCH_FILES} ||= 10;           # Max number of files per batch
	$$params{NJOBS}       ||= 30;           # Max number of parallel transfers
	
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
    my $report = "$$job{DIR}/srm-report";

    # Now generate copyjob
    &output ($spec, join ("", map { "$$tasks{$_}{FROM_PFN} ".
		                    "$$tasks{$_}{TO_PFN}\n" }
		          keys %{$$job{TASKS}}));

    # Fork off the transfer wrapper
    $self->addJob(undef, { DETACHED => 1 },
		  $$self{WRAPPER}, $$job{DIR}, $$self{TIMEOUT},
		  @{$$self{COMMAND}}, "-copyjobfile=$spec", "-report=$report");
}

1;
