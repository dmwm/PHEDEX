package PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging', 'Exporter';
use Data::Dumper;
use Data::UUID;
use File::Path;
use POSIX;
use Switch;
use Time::HiRes qw(time);

use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::File::Download::Circuits::Constants;

our @EXPORT = qw(openState formattedTime getPath);

$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 1;

=pod

This is the base object which describes the common functionality containted by circuits and bandwidth (BOD) objects

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
            # Object parameters
            ID                      => undef,
            NAME                    => undef,
            BOOKING_BACKEND         => 'Dummy',
            
            RESOURCE_TYPE           => undef,               # Dynamic circuit / Bandwidth on demand
            
            NODE_A                  => undef,
            NODE_B                  => undef,
            BIDIRECTIONAL           => 1,                   # 0 for unidirectional circuits/links
                                                            # An unidirectional link doesn't mean it's physically unidirectional
                                                            # It just means that if multiple nodes share a Manager, only the
                                                            # site doing transfers from A->B will be allowed to use the resource
            
            BANDWIDTH_ALLOCATED     => undef,               # Bandwidth allocated
            BANDWIDTH_USED          => undef,               # Bandwidth we're actually using
            
            SCOPE                   => undef,
            STATUS                  => undef,
            LAST_STATUS_CHANGE      => undef,
            
            STATE_DIR               => undef,
            REQUEST_TIMEOUT         => 5*MINUTE,         # in seconds
            
            VERBOSE                 => 0,
    );

    my %args = (@_);

    # use 'defined' instead of testing on value to allow for arguments which are set to zero.
    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    $self->{STATE_DIR} = '/tmp/managed' unless defined $self->{STATE_DIR};
    
    bless $self, $class;

    return $self;
}

sub initResource {
    my ($self, $backend, $type, $nodeA, $nodeB, $bidirectional) = @_;
    
    my $msg = "NetworkResource->initResource";
    
    if  (! defined $backend || ! defined $type || ! defined $nodeA || ! defined $nodeB) {
        $self->Logmsg("$msg: Cannot continue initialisation. One of the provided parameters is invalid");
        return ERROR_GENERIC;
    }
    
    # Initialise ID
    my $ug = new Data::UUID;
    $self->{ID} = $ug->to_string($ug->create());
    
    # Assign resource data
    $self->{BOOKING_BACKEND} = $backend;
    $self->{RESOURCE_TYPE} = $type;
    $self->{NODE_A} = $nodeA;
    $self->{NODE_B} = $nodeB;
    $self->{BIDIRECTIONAL} = $bidirectional ? 1 : 0;
    $self->{NAME} = getPath($nodeA, $nodeB, $self->{BIDIRECTIONAL});
    $self->{LAST_STATUS_CHANGE} = &mytimeofday();
    $self->{SCOPE} = 'GENERIC';
    $self->Logmsg("$msg: Successfully initialised resource. $type between $nodeA and $nodeB");
    
    return OK;
}

sub getSaveParams {
    my $self = shift;
    $self->Fatal("NetworkResource->getSaveParams: method not implemented in extending class ", __PACKAGE__);
}

# Generates a file name in the form of : NODE_A-(to)-NODE_B-UID-time
# ex. T2_ANSE_Amsterdam-to-T2_ANSE_Geneva-FSDAXSDA-20140427-10:00:00, if link is unidirectional
# or T2_ANSE_Amsterdam-T2_ANSE_Geneva-FSDAXSDA-20140427-10:00:00, if link is bi-directional.
# Returns a save path ({STATE_DIR}/[circuits/bod]/$state) and a file path ({STATE_DIR}/[circuits/bod]/$state/$NODE_A-to-$NODE_B-$time)
sub getSavePaths{
    my $self = shift;

    my $msg = "NetworkResource->getSavePaths";
        
    if (! defined $self->{ID}) {
        $self->Logmsg("$msg: Cannot generate a save name for a resource which is not initialised");
        return;
    }
    
    my ($savePath, $saveTime) = $self->getSaveParams();

    if (!defined $savePath || !defined $saveTime || $saveTime <= 0) {
        $self->Logmsg("$msg: Invalid parameters in generating a circuit file name");
        return;
    }

    my $partialID = substr($self->{ID}, 1, 7);
    my $formattedTime = &formattedTime($saveTime);
    my $fileName = $self->{NAME}."-$partialID-".$formattedTime;
    my $filePath = $savePath.'/'.$fileName;

    # savePath: {STATE_DIR}/[circuits|bod]/$state
    # fileName: NODE_A-(to)-NODE_B-UID-time
    # filePath (savePath/fileName): {STATE_DIR}/[circuits|bod]/$state/NODE_A-(to)-NODE_B-UID-time
    return ($savePath, $fileName, $filePath);
}

sub checkCorrectPlacement {
    my ($self, $path) = @_;
    
    my $msg = 'NetworkResource->checkCorrectPlacement';
    
    my ($savePath, $fileName, $filePath) = $self->getSavePaths();
    
    if (! defined $savePath || ! defined $filePath) {
        $self->Logmsg("$msg: Cannot generate save name...");
        return ERROR_GENERIC;
    }
    
    if ($filePath ne $path) {
        $self->Logmsg("$msg: Provided filepath doesn't match where object should be located");
        return ERROR_GENERIC;
    } else {
        return OK;
    }
}

# Saves the current state of the resource
# For this a valid STATE_DIR must be defined
# If it's not specified at construction it will automatically be created in /tmp/managed/{RESOURCE_TYPE}
# Depending on the resource type that's being saved, the STATE_DIR
# Based on its current state, the resource will create additional subfolders
# For ex. a circuit will create /requested, /online, /offline
# A managed bandwidth will create /online, offline
sub saveState { 
    my $self = shift;

    my $msg = 'NetworkResource->saveState';

    # Generate file name based on
    my ($savePath, $fileName, $filePath) = $self->getSavePaths();
    if (! defined $filePath) {
        $self->Logmsg("$msg: An error has occured while generating file name");
        return ERROR_SAVING;
    }

    # Check if state folder existed and create if it didn't
    if (!-d $savePath) {
        File::Path::make_path($savePath, {error => \my $err});
        if (@$err) {
            $self->Logmsg("$msg: State folder did not exist and we were unable to create it");
            return ERROR_SAVING;
        }
    }

    # Save the resource object
    my $file = &output($filePath, Dumper($self));
    if (! $file) {
        $self->Logmsg("$msg: Unable to save state information");
        return ERROR_SAVING;
    } else {
        $self->Logmsg("$msg: State information successfully saved");
        return OK;
    };
}

# Factory like method : returns a new resource object from a state file on disk
# It will throw an error if the resource provided is corrupt
# i.e. it doesn't have an ID, STATUS, RESOURCE_TYPE, BOOKING_BACKEND or nodes defined
sub openState {
    my ($path) = @_;

    return (undef, ERROR_OPENING) unless (-e $path);

    my $resource = &evalinfo($path);

    if (! defined $resource->{ID} ||
        ! defined $resource->{RESOURCE_TYPE} ||
        ! defined $resource->{STATUS} ||
        ! defined $resource->{NODE_A} || ! defined $resource->{NODE_B} ||
        ! defined $resource->{BOOKING_BACKEND} ||
        ! defined $resource->{STATE_DIR} ||
        ! defined $resource->{LAST_STATUS_CHANGE}) {
        return;
    }

    return $resource;
}

# Attempts to remove the state file associated with this circuit
sub removeState {
    my $self = shift;

    my $msg = 'NetworkResource->removeState';

    my ($savePath, $fileName, $filePath) = $self->getSavePaths();
    if (!-d $savePath || !-e $filePath) {
        $self->Logmsg("$msg: There's nothing to remove from the state folders");
        return ERROR_GENERIC;
    }

    return !(unlink $filePath) ? ERROR_GENERIC : OK;
}

sub TO_JSON {
    return { %{ shift() } };
}

# Helper methods #

# Returns the link name in the form of Node1-to-Node2 or Node1-Node2 from two given nodes
sub getPath {
    my ($nodeA, $nodeB, $bidirectional) = @_;
    my $link = $bidirectional? "-":"-to-";
    return defined $nodeA && defined $nodeB ? $nodeA.$link.$nodeB : undef;
}

# Generates a human readable date and time - mostly used when saving, in the state file name
sub formattedTime{
    my ($time, $includeMilis) = @_;

    return if ! defined $time;

    my $milis = '';

    if ($includeMilis) {
        $milis = sprintf("%.4f", $time - int($time));
        $milis  =~ s/^.//;
    }

    return strftime('%Y%m%d-%Hh%Mm%S', gmtime(int($time))).$milis;
}

1;