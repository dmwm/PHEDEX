package PHEDEX::Transfer::Null;
use strict;
use warnings;
use base 'PHEDEX::Transfer::Core';
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use Data::Dumper;

# Special back end that bypasses transfers entirely.  Good for testing.
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;

    # Get derived class arguments and defaults
    my $options = shift || {};
    my $params = shift || {};

    # Set my defaults where not defined by the derived class.
    $params->{PROTOCOLS}   ||= [ 'srm' ];    # Accepted protocols
    $params->{BATCH_FILES} ||= 100;          # Max number of files per batch
    $params->{FAIL_RATE} ||= 0;              # Probability of failure (0 to 1)

    # Set argument parsing at this level.
    $options->{'batch-files=i'}      = \$params->{BATCH_FILES};
    $options->{'fail-rate=f'} = \$params->{FAIL_RATE};

    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);
    bless $self, $class;
    return $self;
}

# No-op transfer batch operation.
sub transferBatch
{
    my ($self, $job, $tasks) = @_;
    my $now = &mytimeofday();

    foreach my $task (keys %{$job->{TASKS}})
    {
	my $info;
	if (rand() < $self->{FAIL_RATE}) {
	    $info = { START => $now, END => $now, STATUS => 1,
		      DETAIL => "nothing done unsuccessfully", LOG => "ERROR" };
	} else {
	    $info = { START => $now, END => $now, STATUS => 0,
		      DETAIL => "nothing done successfully", LOG => "OK" };
	}
	&output("$job->{DIR}/T${task}X", Dumper($info));
    }
}

1;
