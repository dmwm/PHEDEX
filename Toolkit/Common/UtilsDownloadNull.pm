package UtilsDownloadNull; use strict; use warnings; use base 'UtilsDownload';
use UtilsCommand;
use UtilsTiming;
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
	$$params{PROTOCOLS}   ||= [ 'srm' ];    # Accepted protocols
	$$params{BATCH_FILES} ||= 100;          #ÊMax number of files per batch
	
	# Set argument parsing at this level.
	$$options{'batch-files=i'} = \$$params{BATCH_FILES};

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

    foreach my $task (keys %{$$job{TASKS}})
    {
	my $info = { START => $now, END => $now, STATUS => 0,
		     DETAIL => "nothing done", LOG => "" };
	&output("$$job{DIR}/T${task}X", Dumper($info));
    }
}

1;
