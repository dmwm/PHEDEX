package UtilsDownloadNull; use strict; use warnings; use base 'UtilsDownload';
use UtilsLogging;
use Getopt::Long;

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

# Transfer a batch of files.
sub transferBatch
{
    my ($self, $batch) = @_;
    foreach my $file (@$batch)
    {
	$$file{TRANSFER_STATUS}{STATUS} = 0;
	$$file{TRANSFER_STATUS}{REPORT} = "nothing done";

	$$file{DONE_TRANSFER} = 1;
	$self->startFileTiming ($file, "transfer");
	$self->stopFileTiming ($file);
    }
 
    # Move to next stage if all is done.
    $self->validateBatch ($batch);
}

1;
