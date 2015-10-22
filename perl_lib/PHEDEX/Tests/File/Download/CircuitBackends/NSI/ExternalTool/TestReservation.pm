package PHEDEX::Tests::File::Download::CircuitBackends::NSI::ExternalTool::TestReservation;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';

use PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::Reservation;
use PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::ReservationConstants;
use PHEDEX::File::Download::Circuits::ManagedResource::Circuit;

use Test::More;

sub testInitialisation {
    my $reservation = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::Reservation->new();
    
    ok($reservation->{STATE_MACHINE}, "State machine was created");
    is($reservation->{STATE_MACHINE}->{CURRENT_STATE}, STATE_CREATED ,"State machine was correctly initialised");

    my $params = $reservation->{PARAM};
     
    is($params->{BANDWIDTH}->{ARG}, "--bw", "Bandwidth argument was correctly initialised");
    is($params->{BANDWIDTH}->{VALUE}, 1000, "Bandwidth value was correctly initialised");
    is($params->{DESCRIPTION}->{ARG}, "--d", "Description argument was correctly initialised");
    ok($params->{DESCRIPTION}->{VALUE}, "Description value was correctly initialised");
    is($params->{START_TIME}->{ARG}, "--st", "Start time argument was correctly initialised");
    is($params->{START_TIME}->{VALUE}, "10 sec", "Start time value was correctly initialised");
    is($params->{END_TIME}->{ARG}, "--et", "End time argument was correctly initialised");
    is($params->{END_TIME}->{VALUE}, "30 min", "End timevalue was correctly initialised");
    is($params->{GRI}->{ARG}, "--g", "Global resource identifier argument was correctly initialised");
    is($params->{GRI}->{VALUE}, "PhEDEx-NSI", "Global resource identifier value was correctly initialised");
    is($params->{SOURCE_NODE}->{ARG}, "--ss", "Source node argument was correctly initialised");
    is($params->{SOURCE_NODE}->{VALUE}, "urn:ogf:network:somenetwork:somestp?vlan=333", "Source node value was correctly initialised");
    is($params->{DEST_NODE}->{ARG}, "--ds", "Destination node argument was correctly initialised");
    is($params->{DEST_NODE}->{VALUE}, "urn:ogf:network:othernetwork:otherstp?vlan=333", "Destination node value was correctly initialised");
}

sub testOtherMethods {
    my $reservation = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::Reservation->new();
    
    # Make sure that the state machine was correctly initialised
    $reservation->updateState(STATE_ASSIGNED_ID);
    is($reservation->{STATE_MACHINE}->{CURRENT_STATE}, STATE_ASSIGNED_ID, "State machine was updated");

    # Check the getReservationScript method
    my $testCircuit = PHEDEX::File::Download::Circuits::ManagedResource::Circuit->new();
    my $success = $testCircuit->initResource("Dummy", "NODE_A", "NODE_B", 1);
    $testCircuit->{LIFETIME} = 3600;

    my $translation = {
        NODE_A  =>  "URL 1",
        NODE_B  =>  "URL 2",
    };

    $reservation->updateParameters($translation, $testCircuit);
    my $reservationScript = $reservation->getReservationSetterScript();
    my $scriptHash;

    # Yes, this is an ugly way to test it
    foreach my $line (@{$reservationScript}) {
        $scriptHash->{$line} = 1;
    }

    ok($scriptHash->{'resv set --bw "1000"'."\n"}, "BW correctly set");
    ok($scriptHash->{'resv set --ss "URL 1"'."\n"}, "Node 1 correctly set");
    ok($scriptHash->{'resv set --ds "URL 2"'."\n"}, "Node 2 correctly set");
    ok($scriptHash->{'resv set --et "3600 sec"'."\n"}, "Lifetime correctly set");
    ok($scriptHash->{'resv set --st "10 sec"'."\n"}, "Start time correctly set");
    
    # Check the getTermination script method
    my $failedTerminationScript = $reservation->getTerminationScript();
    ok(! defined $failedTerminationScript, "Cannot generate termmination script without knowing the reservation connection id");
     
    $reservation->{CONNECTION_ID} = "d005b619-16be-4312-82bf-4960ebdc6326";
    my $terminationScript = $reservation->getTerminationScript();
    is($terminationScript->[0], "nsi override\n", "First line of termination script looks ok");
    is($terminationScript->[1], "nsi set --c \"d005b619-16be-4312-82bf-4960ebdc6326\"\n", "Second line of termination script looks ok");
    is($terminationScript->[2], "nsi terminate\n", "Third line of termination script looks ok");
}

testInitialisation();
testOtherMethods();

done_testing();

1;