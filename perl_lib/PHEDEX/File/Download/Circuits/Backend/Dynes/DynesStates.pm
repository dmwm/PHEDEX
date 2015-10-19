package PHEDEX::File::Download::Circuits::Backend::Dynes::DynesStates;

use strict;
use warnings;

use Switch;

use constant {
    # The steps that the IDC takes to establish a circuit
    # If we get to the final step (PING), it means that we established a circuit,
    # and that circuit is working, since PING works
    STEP_ORDER      =>  ['DOWN', 'PATH_CALCULATION', 'IN_SETUP', 'ACTIVE', 'ROUTE_ADDED', 'PING'],

    # The REGEX that are used to validate a certain step
    STEP_REGEX      =>  {
        'DOWN'              => "NO REGEX NEEDED",
        'PATH_CALCULATION'  => "Current (OSCARS/)?IDC [s|S]tatus: INPATHCALCULATION",
        'IN_SETUP'          => "Current (OSCARS/)?IDC [s|S]tatus: INSETUP",
        'ACTIVE'            => "Current (OSCARS/)?IDC [s|S]tatus: ACTIVE",
        'ROUTE_ADDED'       => "(ip route add) ([0-9.]*)(/32 via) ([0-9.]*)",
        'PING'              => "(INFO: 64 bytes from )([0-9.]*)(: icmp_seq=[0-9]* ttl=64)"   #TODO: Ping should be checked against dest IP
    },

    # The REGEX that are used to detect any errors
    # We consider PING_FAILED as an error, after 30 unsuccessful ping attemps, since
    # it might be that the first few ping attempts fail sometimes
    ERRORS           =>     {
        'GENERIC'           => "WARNING: Circuit creation failed",
        'PING_FAILED'       => "INFO: From [0-9.]* icmp_seq=30 Destination Host Unreachable", #TODO: Ping should be checked against dest IP
        'REMOTE_ERROR'      => "Remote agent error",
    }
};

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
        CURRENT_STEP    =>  0,          # The index (related to STEP_ORDER) of the last successful step
        SRC_IP          =>  undef,      # Circuit source IP as given by the IDC
        DEST_IP         =>  undef,      # Circuit destinatio IP as given by the IDC
    );

    my %args = (@_);

    #   use 'defined' instead of testing on value to allow for arguments which are set to zero.
    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = \%args;

    bless $self, $class;
    return $self;
}

# Given a certain line from the output of dynesfdt, this method evaluates
# whether or not the next step* has been successfull or if any errors have been
# reported.
# * next step = the step that follows the last scucessfull step
sub updateState {
    my ($self, $output) = @_;

    # Return if the output is undef or empty or if we reached the final step
    return if !defined $output || $output eq "" || $self->{CURRENT_STEP} == scalar @{&STEP_ORDER} - 1;

    # Get the new step in the sequence to be analysed and attempt to find a match
    my $currentStepIndex = $self->{CURRENT_STEP};
    my $nextStep = STEP_ORDER->[$currentStepIndex + 1];
    my $nextRegex = STEP_REGEX->{$nextStep};
    my @matches = $output =~ /$nextRegex/;

    if (@matches) {
        # If we found a match and this step is "ROUTE ADDED",
        # we need to get the source and destination IPs of the new circuit endpoints
        ($self->{SRC_IP}, $self->{DEST_IP}) = @matches[3, 1] if $nextStep eq 'ROUTE_ADDED';

        # Advance to the next step
        $self->{CURRENT_STEP} = $currentStepIndex + 1;
        return ['OK', STEP_ORDER->[$self->{CURRENT_STEP}]];
    }

    # Check for errors as well
    foreach my $error (keys %{&ERRORS}) {
        my $errorRegex = ERRORS->{$error};
        my @errorMatches = $output =~ /$errorRegex/;
        if (@errorMatches) {
            return ['ERROR', $error];
        }
    }
}


1;