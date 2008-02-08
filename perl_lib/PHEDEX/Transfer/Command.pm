package PHEDEX::Transfer::Command; use strict; use warnings; use base 'PHEDEX::Transfer::Core';
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
	$$params{COMMAND}     ||= undef;        # Transfer command
	$$params{NJOBS}       ||= 1;            # Max number of parallel transfers
	$$params{BATCH_FILES} ||= 1;            # Max number of files per batch
	$$params{TIMEOUT}     ||= 3600;         # Maximum execution time
	
	# Set argument parsing at this level.
	$$options{'command=s'} = sub { $$params{COMMAND} = [ split(/,/, $_[1]) ] };
	$$options{'jobs=i'}    = \$$params{NJOBS};
	$$options{'timeout=i'} = \$$params{TIMEOUT};

    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);
    bless $self, $class;
    return $self;
}

# Transfer batch of files.  Forks off the transfer wrapper for each
# file in the copy job (= one source, destination file pair).
sub transferBatch
{
    my ($self, $job, $tasks) = @_;
    foreach (keys %{$$job{TASKS}})
    {
        $self->addJob(undef, { DETACHED => 1 },
		      $$self{WRAPPER}, $$job{DIR}, $$self{TIMEOUT},
		      @{$$self{COMMAND}}, $$tasks{$_}{FROM_PFN},
		      $$tasks{$_}{TO_PFN});
    }
}

1;
