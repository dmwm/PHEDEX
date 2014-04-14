package PHEDEX::File::Download::Circuits::ManagedResource::Bandwidth;

use strict;
use warnings;

use base 'PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource', 'PHEDEX::Core::Logging', 'Exporter';
use Data::UUID;
use POE;
use POSIX "fmod";
use Switch;

use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource;
use PHEDEX::Core::Timing;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
            # Object params
            BANDWIDTH_STEP          =>  1,      # Given in Gbps
            BANDWIDTH_MIN           =>  0,      # Given in multiples of BANDWIDTH_STEP (0 accepted - actually means taking the link down) 
            BANDWIDTH_MAX           =>  1000,   # Given in multiples of BANDWIDTH_STEP
            BANDWIDTH_REQUESTED     =>  undef   # Surprise surprise, also given in multiples of BANDWIDTH_STEP
    );

    my %args = (@_);

    #   use 'defined' instead of testing on value to allow for arguments which are set to zero.
    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    bless $self, $class;

    return $self;
}

sub initResource {
    my ($self, $backend, $nodeA, $nodeB, $bidirectional) = @_;
    
    # Do our own initialisation
    $self->{STATE_DIR}.="/bod";
    $self->{STATUS} = STATUS_OFFLINE;
    $self->{BANDWIDTH_ALLOCATED} = 0;
    
    return $self->SUPER::initResource($backend, BOD, $nodeA, $nodeB, $bidirectional);
}

# Returns what the save path and save time should be based on current status
sub getSaveParams {
    my $self = shift;
    my ($savePath, $saveTime);
    
    # Bandwidth object will be either put in /offline or /online
    # As opposed to circuit, it's not useful to have a 3rd folder called "/updating"
    # since in the case of BoD the path should remain up even when updating
    # The object goes into the /offline folder if status if offline, or updating and allocated bw = 0
    # Goes into /online for the rest of the cases
    if ($self->{STATUS} == STATUS_OFFLINE ||
        $self->{STATUS} == STATUS_UPDATING && $self->{BANDWIDTH_ALLOCATED} == 0) {
        $savePath = $self->{STATE_DIR}.'/offline';
    } else {
        $savePath = $self->{STATE_DIR}.'/online';
    }
    
    $saveTime = $self->{LAST_STATUS_CHANGE};
    
    return ($savePath, $saveTime);
}

# Used to register a bandwidth update request 
sub registerUpdateRequest {
    my ($self, $bandwidth, $force) = @_;

    my $msg = 'Bandwidth->registerUpdateRequest';

    if ($self->{STATUS} == STATUS_UPDATING) {
        $self->Logmsg("$msg: Cannot request an update. Update already in progress");
        return ERROR_GENERIC;
    }
    
    return ERROR_GENERIC if $self->validateBandwidth($bandwidth) != OK;
    
    # Check if what we're asking is not already here
    if ($self->{BANDWIDTH_ALLOCATED} > $bandwidth && !$force) {
        $self->Logmsg("$msg: Bandwidth you requested for is already there...");
        return BOD_UPDATE_REDUNDANT;
    }
    
    # TODO: Differentiate between ajusting bandwidth up or down
    $self->{STATUS} = STATUS_UPDATING;
    $self->{BANDWIDTH_REQUESTED} = $bandwidth;
    $self->{LAST_STATUS_CHANGE} = &mytimeofday();

    $self->Logmsg("$msg: state has been switched to STATUS_UPDATING");

    return OK;
}

# Used to register the new bandwidth following an update request
sub registerUpdateSuccessful {
    my $self = shift;

    my $msg = 'Bandwidth->registerUpdateSuccessful';

    if ($self->{STATUS} != STATUS_UPDATING) {
        $self->Logmsg("$msg: Cannot update status if we're not in updating mode already");
        return ERROR_GENERIC;
    }
    
    if (! defined $self->{BANDWIDTH_REQUESTED}) {
        $self->Logmsg("$msg: Something fishy has happened. BANDWIDTH_REQUESTED is not defined...");
        return ERROR_GENERIC;
    }
    
    $self->{BANDWIDTH_ALLOCATED} = $self->{BANDWIDTH_REQUESTED};
    $self->{BANDWIDTH_REQUESTED} = undef;
    
    if ($self->{BANDWIDTH_ALLOCATED} == 0) {
        $self->Logmsg("$msg: Effectively turning off the resource (by requesting BW of 0)");
        $self->{STATUS} = STATUS_OFFLINE;
    } else {
        $self->Logmsg("$msg: Bandwidth capacity updated");
        $self->{STATUS} = STATUS_ONLINE;
    }
    
    return OK;
}

# TODO: Assuming that when an update request fails, it just means it gets denied, thus
# previous reserved bandwidth is still in place. Need to update if this is not the case
# TODO: Do we need to remember this failure? If we do, also add support for storing reason  
sub registerUpdateFailed {
    my $self = shift;
    
    my $msg = 'Bandwidth->registerUpdateFailed';
    
    if ($self->{STATUS} != STATUS_UPDATING) {
        $self->Logmsg("$msg: Cannot update status if we're not in updating mode already");
        return ERROR_GENERIC;
    }
    
    $self->{BANDWIDTH_REQUESTED} = undef;
    $self->{STATUS} = $self->{BANDWIDTH_ALLOCATED} == 0 ? STATUS_OFFLINE : STATUS_ONLINE;
    
    return OK;
}

sub validateBandwidth {
    my ($self, $bandwidth) = @_;

    my $msg = 'Bandwidth->validateBandwidth';

    # Check that the bandwidth was correctly specified
    if (! defined $bandwidth || 
        $bandwidth < $self->{BANDWIDTH_MIN} || $bandwidth > $self->{BANDWIDTH_MAX} ||
        fmod($bandwidth, $self->{BANDWIDTH_STEP}) != 0) {
        $self->Logmsg("$msg: Invalid bandwidth request");
        return ERROR_GENERIC;
    } else {
        return OK;
    }
}

1;
