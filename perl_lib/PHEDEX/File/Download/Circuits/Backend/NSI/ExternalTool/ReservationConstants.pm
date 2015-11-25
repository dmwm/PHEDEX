package PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw(
                STATE_CREATED STATE_ASSIGNED_ID STATE_CONFIRMED STATE_COMMITTED STATE_PROVISIONED STATE_ACTIVE STATE_TERMINATED
                STATE_ERROR STATE_ERROR_CONFIRM_FAIL STATE_ERROR_COMMIT_FAIL STATE_ERROR_PROVISION_FAIL
                RESERVATION_TRANSITIONS
                identifyNextState isValidState
                );

use constant CONNECTION_ID_REGEX => "(([\\d\\w]{8})((-[\\d\\w]{4}){3})-([\\d\\w]{12}))";

# Define the list of possible states and the regular expressions that allow for
# transitions between the various states
use constant {
    # States
    STATE_CREATED               =>  "Reservation created",
    STATE_ASSIGNED_ID           =>  "Reservation has an ID assigned",
    STATE_CONFIRMED             =>  "Reservation confirmed",
    STATE_COMMITTED             =>  "Reservation committed",
    STATE_PROVISIONED           =>  "Reservation provisioned",
    STATE_ACTIVE                =>  "Dataplane active",
    STATE_TERMINATED            =>  "Reservation terminated",
    STATE_ERROR                 =>  "Generic failure",
    STATE_ERROR_CONFIRM_FAIL    =>  "Failed to confirm reservation",
    STATE_ERROR_COMMIT_FAIL     =>  "Failed to commit reservation",
    STATE_ERROR_PROVISION_FAIL  =>  "Failed to provisino reservation",

    # RegEx
    REGEX_ASSIGNED_ID           =>  "Submitted reserve, new connectionId = ".CONNECTION_ID_REGEX,
    REGEX_CONFIRMED             =>  "Received reserveConfirmed for connectionId: ".CONNECTION_ID_REGEX,
    REGEX_CONFIRM_FAIL          =>  "Received reserveFailed for connectionId: ".CONNECTION_ID_REGEX,
    REGEX_COMMITTED             =>  "Received reserveCommitConfirmed for connectionId: ".CONNECTION_ID_REGEX,
    REGEX_COMMIT_FAIL           =>  "Received reserveCommitFailed for connectionId: ".CONNECTION_ID_REGEX,
    REGEX_PROVISIONED           =>  "Received provisionConfirmed for connectionId: ".CONNECTION_ID_REGEX,
    REGEX_PROVISION_FAIL        =>  "Received provisionFailed for connectionId: ".CONNECTION_ID_REGEX,
    REGEX_ACTIVE                =>  "Received dataPlaneStateChange for connectionId: ".CONNECTION_ID_REGEX,
    REGEX_TERMINATED            =>  "Received terminationConfirmed for connectionId: ".CONNECTION_ID_REGEX,         # TODO: Recheck this REGEX
    REGEX_GENERIC_FAIL          =>  "Received an errorEvent for connectionId: ".CONNECTION_ID_REGEX,
};

# Define the state machine transitions: 
# given a state, list the possible next states based on a given message
use constant {
    RESERVATION_TRANSITIONS => {
        STATE_CREATED() => {
            REGEX_ASSIGNED_ID()     => STATE_ASSIGNED_ID,
            REGEX_GENERIC_FAIL()    => STATE_ERROR,
        },
        STATE_ASSIGNED_ID() => {
            REGEX_CONFIRMED()       => STATE_CONFIRMED,
            REGEX_CONFIRM_FAIL()    => STATE_ERROR_CONFIRM_FAIL,
            REGEX_GENERIC_FAIL()    => STATE_ERROR,
        },
        STATE_CONFIRMED()   => {
            REGEX_COMMITTED()       => STATE_COMMITTED,
            REGEX_COMMIT_FAIL()     => STATE_ERROR_COMMIT_FAIL,
            REGEX_GENERIC_FAIL()    => STATE_ERROR,
        },
        STATE_COMMITTED()   => {
            REGEX_PROVISIONED()     => STATE_PROVISIONED,
            REGEX_GENERIC_FAIL()    => STATE_ERROR,
        },
        STATE_PROVISIONED()   => {
            REGEX_ACTIVE()          => STATE_ACTIVE,
            REGEX_PROVISION_FAIL()  => STATE_ERROR_PROVISION_FAIL,
            REGEX_GENERIC_FAIL()    => STATE_ERROR,
        },
        STATE_ACTIVE()   => {
            REGEX_TERMINATED()      => STATE_TERMINATED,
        },
    }
};

my ($states, $allRegex);

# Creates a list of all possible states and possible regular expressions
# This will only be done once, first time this method is called
sub doCensus {
    if (! defined $states || ! defined $allRegex) {
        foreach my $transitionKey (keys %{RESERVATION_TRANSITIONS()}) {
            $states->{$transitionKey} = 1;
            foreach my $message (keys %{RESERVATION_TRANSITIONS->{$transitionKey}}) {
                my $state = RESERVATION_TRANSITIONS->{$transitionKey}->{$message};
                $allRegex->{$message} = $state;
                $states->{$state} = 1;
            }
        }
    }
}

# Checks if the given state is found among the possible states defined by this class
sub isValidState {
    my ($self, $state) = @_;
    doCensus();
    return $states->{$state};
}

# Identified the next logical state based on the message that was passed on
sub identifyNextState {
    my ($self, $output) = @_;
    doCensus();
    # Get the next state (and connection ID) based on the message
    foreach my $regex (%{$allRegex}) {
         my @matches = $output =~ /$regex/;
         if (@matches) {
             my $connectionID = $matches[0];
             my $nextState = $allRegex->{$regex};
             return [$connectionID, $nextState];
         }
    }
    return undef;
}

1;