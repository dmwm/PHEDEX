package UtilsDownloadNull; use strict; use warnings; use base 'UtilsDownload';
use UtilsLogging;
use UtilsCommand;
use UtilsTiming;
use Getopt::Long;
use Data::Dumper;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = (@_);

    # Initialise myself
    my $self = $class->SUPER::new(%args);
    my %default= (PROTOCOLS	=> [ "srm" ],	# Accepted protocols
		  BATCH_FILES	=> 100);	# Max number of files per batch

    $$self{$_} = $$self{$_} || $default{$_} for keys %default;
    bless $self, $class;
    return $self;
}

# Create one copy job.
sub startBatch
{
    my ($self, $jobs, $tasks, $dir, $jobname, $list) = @_;
    my @batch = splice(@$list, 0, $$self{BATCH_FILES});
    my $now = &mytimeofday();

    my $info = { TASKS => { map { $$_{TASKID} => 1 } @batch } };
    &output("$dir/info", Dumper($info));
    &touch("$dir/live");

    foreach my $task (@batch)
    {
	# FIXME: pre-clean
	my $info = { START => $now, END => $now, STATUS => 0,
		     DETAIL => "nothing done", LOG => "" };
	&output("$dir/T$$task{TASKID}X", Dumper($info));
        $$self{MASTER}->saveTask($task);
    }
}

1;
