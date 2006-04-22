package UtilsDownloadGlobus; use strict; use warnings; use base 'UtilsDownload';
use UtilsLogging;
use Getopt::Long;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %args = (@_);

    # Parse backend-specific additional options
    local @ARGV = @{$args{BACKEND_ARGS}};
    Getopt::Long::Configure qw(default pass_through require_order);
    &GetOptions ("command=s" => sub { push(@{$args{COMMAND}},
					   split(/,/, $_[1])) });

    # Initialise myself
    my $self = $class->SUPER::new(%args);
    my $defcmd = [ qw(globus-url-copy -p 5 -tcp-bs 2097152) ];
    my %params = (COMMAND	=> $defcmd);	# Transfer command
    my %default= (PROTOCOLS	=> [ "gsiftp" ],# Accepted protocols
		  BATCH_FILES	=> 1);		# Max number of bytes per batch

    $$self{$_} = $args{$_} || $params{$_} || $$self{$_} || $default{$_}
	for keys %params, keys %default;

    # Ensure batch transfers are supported by globus-url-copy if requested.
    # Assume any 3.x or newer version does.
    if ($$self{BATCH_FILES} > 1)
    {
	if (! open (GUC, "$$self{COMMAND}[0] -version 2>&1 |")
	    || grep (/^globus-url-copy:\s*(\d+)(\.\d*)*\s*$/ && $1 < 3, <GUC>))
	{
	    &logmsg ("turning off batch transfers, not supported by globus-url-copy");
	    $$self{BATCH_FILES} = 1;
	}
	close (GUC);
    }

    bless $self, $class;
    return $self;
}

# Transfer batch of files.  Create as many batches as we can.  This
# depends on source/dest directories and whether source/destination
# file name parts match.
sub transferBatch
{
    my ($self, $batch, $files, $job) = @_;
    if ($job)
    {
	# Reap finished jobs
	foreach my $file (@$files)
	{
	    $$file{DONE_TRANSFER} = 1;
	    $$file{TRANSFER_STATUS}{STATUS} = $$job{STATUS};
	    $$file{TRANSFER_STATUS}{REPORT}
	        = "exit code $$job{STATUS} from @{$$job{CMD}}";
	    $self->stopFileTiming ($file);
	}
    }
    else
    {
	# First time around initiate transfers all files.
        my %groups = ();
        foreach my $file (@$batch)
        {
	    next if $$file{DONE_TRANSFER};
	    do { $$file{DONE_TRANSFER} = 1; next } if $$file{FAILURE};
	    $self->startFileTiming ($file, "transfer");

	    # Put this file into a transfer group.  If the files have the
	    # same file name component at the source and destination, we
	    # can group several transfers together by destination dir.
	    # Otherwise we have to make individual transfers.
	    my ($from_pfn, $to_pfn) = ($$file{FROM_PFN}, $$file{TO_PFN});
	    my ($from_dir, $from_file) = ($from_pfn =~ m|(.*)/([^/]+)$|);
	    my ($to_dir, $to_file) = ($to_pfn =~ m|(.*)/([^/]+)$|);

	    # If destination LFNs are equal and we attempt batch transfers,
	    # try to create optimal transfer groups.  Otherwise don't bother;
	    # if batch transfers are off, underlying globus-url-copy might
	    # not even support directories as destinations.
	    if ($from_file eq $to_file && $$self{BATCH_FILES} > 1) {
		push (@{$groups{$to_dir}}, { FILE => $file, PATH => $from_pfn });
	    } else {
		push (@{$groups{$to_pfn}}, { FILE => $file, PATH => $from_pfn });
	    }
        }

        # Now start transfer groups.
        foreach my $dest (keys %groups)
        {
	    # FIXME: globus-url-copy 3.x support copyjob files like SRM.
	    my @files = @{$groups{$dest}};
	    my @sourcefiles = map { $$_{FILE} } @files;
	    my @sourcepaths = map { $$_{PATH} } @files;
	    $self->addJob (
		sub { $self->transferBatch ($batch, \@sourcefiles, @_) },
	        { TIMEOUT => $$self{TIMEOUT} },
	        @{$$self{COMMAND}}, @sourcepaths, $dest);
        }
    }

    # Move to next stage if all is done.
    $self->validateBatch ($batch)
        if ! grep (! $$_{DONE_TRANSFER}, @$batch);
}

1;
