package PHEDEX::Tests::File::Download::StressTestConcurrentCircuits;

use strict;
use warnings;

use File::Copy qw(move);
use PHEDEX::Core::Timing;
use PHEDEX::File::Download::Circuits::ManagedResource::Circuit;
use PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource;
use PHEDEX::File::Download::Circuits::ResourceManager;
use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::Tests::File::Download::Helpers::ObjectCreation;
use PHEDEX::Tests::File::Download::Helpers::SessionCreation;
use POE;
use POSIX;
use Test::More;

# This test consists of creating many circuits in order to determine how the ResourceManager handles the workload
sub testMaxCircuitCount {

    our $allMyCircuits = 1000;

    # Intermediate test that checks that requests were actually created
    sub iTestMaxRequestCount {
        my $circuitManager = $_[ARG0];

        for (my $i = 1; $i < $allMyCircuits; $i++) {
            my $linkName = "T2_ANSE_CERN_X-to-T2_ANSE_CERN_$i";
            my $circuit = $circuitManager->{RESOURCES}{$linkName};

            is($circuit->{STATUS}, STATUS_UPDATING, "StressTestConcurrentCircuits->requestCircuit - circuit $i status in circuit manager is correct");

            my $partialID = substr($circuit->{ID}, 1, 7);
            my $time = $circuit->{REQUEST_TIME};
            my $fileReq = $baseLocation."/data/circuits/requested/$linkName-$partialID-".formattedTime($time);

            ok(-e $fileReq, "StressTestConcurrentCircuits->requestCircuit - circuit $i has been requested");

            my $openedCircuit= &openState($fileReq);
            ok($openedCircuit, "StressTestConcurrentCircuits->requestCircuit - was able to open saved state for circuit $i");

            is($openedCircuit->{NODE_A}, 'T2_ANSE_CERN_X', "StressTestConcurrentCircuits->requestCircuit - circuit $i from node ok");
            is($openedCircuit->{NODE_B}, "T2_ANSE_CERN_$i", "StressTestConcurrentCircuits->requestCircuit - circuit $i to node ok");
        }
    }

    # Intermediate test that checks that requests were switched to active circuits
    sub iTestMaxSwitchToEstablished {
        my $circuitManager = $_[ARG0];

        for (my $i = 1; $i < $allMyCircuits; $i++) {
            my $c = int($i / 255);
            my $d = $i % 256;

            my $ip = "127.0.$c.$d";

            my $linkName = "T2_ANSE_CERN_X-to-T2_ANSE_CERN_$i";
            my $circuit = $circuitManager->{RESOURCES}{$linkName};

            is($circuit->{STATUS}, STATUS_ONLINE, "StressTestConcurrentCircuits->established - circuit $i status in circuit manager is correct");

            my $partialID = substr($circuit->{ID}, 1, 7);
            my $requestedtime = $circuit->{REQUEST_TIME};
            my $establishedtime = $circuit->{ESTABLISHED_TIME};

            my $fileRequested = $baseLocation."/data/circuits/requested/$linkName-$partialID-".formattedTime($requestedtime);
            my $fileEstablished = $baseLocation."/data/circuits/online/$linkName-$partialID-".formattedTime($establishedtime);

            ok(!-e $fileRequested, "StressTestConcurrentCircuits->established - request for circuit $i has been removed");
            ok(-e $fileEstablished, "StressTestConcurrentCircuits->established - circuit $i has been established");

            my $openedCircuit = &openState($fileEstablished);
            ok($openedCircuit, "StressTestConcurrentCircuits->established - was able to open saved state for circuit $i");

            is($openedCircuit->{IP_A}, '127.1.0.1', "StressTestConcurrentCircuits->established - circuit $i from ip ok");
            is($openedCircuit->{IP_B}, $ip, "StressTestConcurrentCircuits->established - circuit $i to ip ok");
            ok($openedCircuit->{LIFETIME}, "StressTestConcurrentCircuits->established - circuit $i has a life set");
        }
    }
#
    # Intermediate test that checks that the circuit which had a lifetime expired
    sub iTestMaxSwitchToOffline {
        my $circuitManager = $_[ARG0];

        for (my $i = 1; $i < $allMyCircuits; $i++) {
            my $linkName = "T2_ANSE_CERN_X-to-T2_ANSE_CERN_$i";
            my $circuitID = $circuitManager->{RESOURCE_HISTORY}{$linkName};
            my $circuit = $circuitID->{(keys %{$circuitID})[0]};

            is($circuit->{STATUS}, STATUS_OFFLINE, "StressTestConcurrentCircuits->teardownCircuit - circuit $i status in circuit manager is correct");

            my $partialID = substr($circuit->{ID}, 1, 7);
            my $establishedtime = $circuit->{ESTABLISHED_TIME};
            my $offlinetime = $circuit->{LAST_STATUS_CHANGE};

            my $fileEstablished = $baseLocation."/data/circuits/online/$linkName-$partialID-".formattedTime($establishedtime);
            my $fileOffline = $baseLocation."/data/circuits/offline/$linkName-$partialID-".formattedTime($offlinetime);

            ok(!-e $fileEstablished, "StressTestConcurrentCircuits->teardownCircuit - request for circuit $i has been removed");
            ok(-e $fileOffline, "StressTestConcurrentCircuits->teardownCircuit - circuit $i has been established");

            my $openedCircuit = &openState($fileOffline);
            ok($openedCircuit, "StressTestConcurrentCircuits->established - was able to open saved state for circuit $i");
        }
    }

    my ($circuitManager, $session) = setupResourceManager(15, 'creating--many-circuits.log', undef,
                                                            [[\&iTestMaxRequestCount, 2],
                                                             [\&iTestMaxSwitchToEstablished, 6],
                                                             [\&iTestMaxSwitchToOffline, 12]]);

    $circuitManager->Logmsg('Testing events requestCircuit, handleRequestResponse and teardownCircuit');
    $circuitManager->{BACKEND}{TIME_SIMULATION} = 3; # Wait some time before actually establishing the circuit



    $circuitManager->{BACKEND}{AGENT_TRANSLATION}{"T2_ANSE_CERN_X"} = PHEDEX::File::Download::Circuits::Backend::Core::IDC->new(IP => "127.1.0.1");

    # Create all the necessary entries in the backend AGENT_TRANSLATION hash
    for (my $i = 1; $i < $allMyCircuits; $i++) {

        my $c = int($i / 255);
        my $d = $i % 256;

        my $idc = PHEDEX::File::Download::Circuits::Backend::Core::IDC->new(IP => "127.0.$c.$d");
        $circuitManager->{BACKEND}{AGENT_TRANSLATION}{"T2_ANSE_CERN_$i"} = $idc;

        # Request this circuit
        POE::Kernel->post($session, 'requestCircuit',  'T2_ANSE_CERN_X', 'T2_ANSE_CERN_'.$i, 4);
    }

    ### Run POE
    POE::Kernel->run();
}

File::Path::rmtree("$baseLocation".'/logs', 1, 1) if (-d "$baseLocation".'/logs');
File::Path::make_path("$baseLocation".'/logs', { error => \my $err});

testMaxCircuitCount();

done_testing();

1;