package UtilsDownloadCommand; use strict; use warnings; use base 'UtilsDownload';
use Getopt::Long;

# General transfer back end for making file copies with a simple
# command taking one pair of source and destination file names.
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;
    my %args;

    # Parse backend-specific additional options
    local @ARGV = @{$$master{BACKEND_ARGS}};
    Getopt::Long::Configure qw(default pass_through norequire_order);
    &GetOptions ("command=s" => sub { push(@{$args{COMMAND}},
					   split(/,/, $_[1])) },
		 "jobs=i"    => \$args{NJOBS},
	 	 "timeout=i" => \$args{TIMEOUT});

    # Initialise myself
    my $self = $class->SUPER::new($master, @_);
    my %params = (COMMAND	=> undef,	# Transfer command.
		  NJOBS		=> undef,	# Max number of parallel transfers
		  TIMEOUT	=> undef,	# Maximum execution time
	    	  BATCH_FILES	=> 1);		# One file per transfer.
    $$self{$_} = $args{$_} || $$self{$_} || $params{$_} for keys %params;
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
