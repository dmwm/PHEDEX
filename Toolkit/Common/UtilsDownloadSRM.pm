package UtilsDownloadSRM; use strict; use warnings; use base 'UtilsDownloadCommand';
use UtilsLogging;
use UtilsCommand;
use Getopt::Long;

# Command back end defaulting to srmcp and supporting batch transfers.
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;
    my %args;

    # Parse backend-specific additional options
    local @ARGV = @{$$master{BACKEND_ARGS}};
    Getopt::Long::Configure qw(default pass_through norequire_order);
    &GetOptions ("batch-files=i" => \$args{BATCH_FILES});

    # Initialise myself
    my $self = $class->SUPER::new($master, @_);
    my %default= (PROTOCOLS	=> [ "srm" ],	# Accepted protocols
		  COMMAND	=> [ "srmcp" ], # Transfer command
		  BATCH_FILES	=> 10);		# Max number of files per batch

    $$self{$_} = $args{$_} || $$self{$_} || $default{$_} for keys %default;
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
    $self->launch ($$self{WRAPPER}, $$job{DIR}, $$self{TIMEOUT},
	@{$$self{COMMAND}}, "-copyjobfile=$spec", "-report=$report");
}

1;
