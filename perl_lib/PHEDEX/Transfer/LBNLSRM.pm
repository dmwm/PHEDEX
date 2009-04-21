package PHEDEX::Transfer::LBNLSRM;
use strict;
use warnings;
use base 'PHEDEX::Transfer::Command';
use PHEDEX::Core::Command;
use Getopt::Long;

# Command back end defaulting to srmcp and supporting batch transfers.
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
	$params->{COMMAND}     ||= [ 'srm-copy' ];  # Transfer command
	$params->{BATCH_FILES} ||= 10;           # Max number of files per batch
	$params->{NJOBS}       ||= 30;           # Max number of parallel transfers
	
	# Set argument parsing at this level.
	$options->{'batch-files=i'} = \$params->{BATCH_FILES};

    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);
    bless $self, $class;
    return $self;
}

# Transfer a batch of files.
sub transferBatch
{
    my ($self, $job, $tasks) = @_;

    # Prepare copyjob and report names.
    my $spec = "$job->{DIR}/copyjob";
    my $report = "$job->{DIR}/srm-report";

    # Now generate copyjob

#<?xml version="1.0" encoding="UTF-8"?>
#<request>
#  <file>
#    <sourceurl>srm://bestman.lbl.gov:8443/srm/v2/server?SFN=/mydir/my.source.file</sourceurl>
#    <targeturl>srm://bestman2.lbl.gov:8443/srm/v2/server?SFN=/mydir/my.target.file</targeturl>
#  </file>
#</request>

    # Now generate copyjob
    &output ($spec, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<request>\n" . join ("", map { " <file>\n  <sourceurl>$tasks->{$_}{FROM_PFN}</sourceurl>\n  <targeturl>$tasks->{$_}{TO_PFN}</targeturl>\n </file>\n" } keys %{$job->{TASKS}}) . "</request>");

    # Fork off the transfer wrapper
    $self->addJob(undef, { DETACHED => 1 },
		  $self->{WRAPPER}, $job->{DIR}, $self->{TIMEOUT},
		  @{$self->{COMMAND}}, "-f $spec", "-report $report", "-xmlreport $report.xml");
}

1;
