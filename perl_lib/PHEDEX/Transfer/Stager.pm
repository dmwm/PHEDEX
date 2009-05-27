package PHEDEX::Transfer::Stager;
use base 'PHEDEX::Transfer::SRM';

use PHEDEX::Core::Command;
use Getopt::Long;

use strict;
use warnings;

# Command back end defaulting to stagercp script, which emulates srmcp
# For "transfering" files via the staging mechanism
sub new
{
    my $proto  = shift;
    my $class  = ref($proto) || $proto;
    my $master = shift;
    
    # Get derived class arguments and defaults
    my $options = shift || {};
    my $params  = shift || {};

    # Set my defaults where not defined by the derived class.
    $params->{PROTOCOLS}   ||= [ 'direct' ];      # Accepted protocols
    $params->{COMMAND}     ||= [ 'stagercp' ];    # Transfer command
    $params->{BATCH_FILES} ||= 1;                 # Default number of files per batch
    $params->{NJOBS}       ||= 100;               # Default number of parallel transfers
    $params->{SYNTAX}      ||= "dcache";          # SRM command flavor we are emulating
	
    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);
    bless $self, $class;
    return $self;
}

# The required backend event, start_transfer_job, comes as-is from the
# SRM backend. The stagercp command emulates the behavior of the
# dcache srmcp tool.  The only thing we need to do differently is when
# writing the copyjob file, as stagercp only needs the destination
# PFN.

sub writeSpec
{
    my ($self, $spec, @tasks) = @_;
    my $rv = &output ($spec, join ("", map { "$_->{TO_PFN}\n" } @tasks));
    return $rv;
}

1;
