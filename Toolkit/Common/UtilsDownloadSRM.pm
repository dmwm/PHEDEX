package UtilsDownloadSRM; use strict; use warnings; use base 'UtilsDownload';
use UtilsLogging;
use UtilsCommand;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (COMMAND => [ 'srmcp' ]); # Transfer command
    my %args = (@_);
    map { $self->{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Transfer batch of files with a single srmcp command.
sub transferBatch
{
    my ($self, $master, $batch, $job) = @_;
    my $pending = 0;
    my @copyjob = ();
    my $batchid = undef;
    foreach my $file (@$batch)
    {
	if ($job && grep ($_ eq $file, @{$job->{FOR_FILES}}))
	{
	     $file->{DONE_TRANSFER} = 1;
	     $file->{FAILURE} = "exit code $job->{STATUS} from @{$job->{CMD}}"
	         if $job->{STATUS};
	}

	next if $file->{FAILURE};

	if (! exists $file->{DONE_TRANSFER})
	{
	     # Put this file into a transfer batch
	     my $from_pfn = $file->{FROM_PFN}; $from_pfn =~ s/^[a-z]+:/srm:/;
	     my $to_pfn = $file->{TO_PFN}; $to_pfn =~ s/^[a-z]+:/srm:/;
	     push (@copyjob, { FILE => $file, FROM => $from_pfn, TO => $to_pfn });
	     $file->{DONE_TRANSFER} = undef;
	     $batchid = $file->{BATCHID};
        }

	$pending++ if ! $file->{DONE_TRANSFER};
    }

    # Initiate the copy job
    if (scalar @copyjob)
    {
	my $specfile = "$master->{DROPDIR}/copyjob.$batchid";
	if (! &output ($specfile, join ("", map { "$_->{FROM} $_->{TO}\n" } @copyjob)))
	{
	    # Report and ignore the error, and come back another time.
	    &alert ("failed to create copyjob for batch $batchid");
	    $master->addJob (sub { $self->transferBatch ($master, $batch) });
	    map { delete $_->{DONE_TRANSFER} } @$batch;
	}

	$master->addJob (sub { $self->transferBatch ($master, $batch, @_) },
			 { FOR_FILES => [ map { $_->{FILE} } @copyjob ] },
			 @{$self->{COMMAND}}, "-copyjobfile=$specfile");
    }

    # Move to next stage if all is done.
    $self->updateCatalogue ($master, $batch) if ! $pending;
}

1;
