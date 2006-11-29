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

    # Initialise myself
    my $self = $class->SUPER::new($master, @_);
    my %default= (PROTOCOLS	=> [ "srm" ],	# Accepted protocols
		  BATCH_FILES	=> 100);	# Max number of files per batch

    $$self{$_} ||= $default{$_} for keys %default;
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
