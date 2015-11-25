package PHEDEX::Tests::File::Download::CircuitBackends::TestML;


use strict;
use warnings;

use POE;
use Test::More;

use PHEDEX::File::Download::Circuits::Backend::Helpers::HttpClient;
use PHEDEX::File::Download::Circuits::ManagedResource::Circuit;
use PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource;
use PHEDEX::File::Download::Circuits::ResourceManager;
use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::Tests::File::Download::Helpers::ObjectCreation;
use PHEDEX::Tests::File::Download::Helpers::SessionCreation;


# This test checks to see if the ML backend works properly
sub testMLBackend {

    # Request a circuit
    sub iRequestCircuit {
        my ($kernel, $session, $circuitManager) = @_[KERNEL, SESSION, ARG0];
        $kernel->post($session, 'requestCircuit', 'T2_ANSE_CERN_1', 'T2_ANSE_CERN_2', 120, 1000);
    };

    # Test that the request has actually been established
    sub iTestCircuitRequest {
        my $circuitManager = $_[ARG0];

        my $linkName = "T2_ANSE_CERN_1-to-T2_ANSE_CERN_2";
        my $circuit = $circuitManager->{CIRCUITS}{$linkName};

        is($circuit->{STATUS}, STATUS_UPDATING, "iTestCircuitRequest: circuit status in circuit manager is correct");
        is($circuit->{NODE_A}, "T2_ANSE_CERN_1", "iTestCircuitRequest: circuit request validated FROM parameter");
        is($circuit->{NODE_B}, "T2_ANSE_CERN_2", "iTestCircuitRequest: circuit request validated TO parameter");
        
        my $partialID = substr($circuit->{ID}, 1, 8);
        my $time = $circuit->{REQUEST_TIME};
        my $fileReq = $baseLocation."/data/circuits/requested/$linkName-$partialID-".formattedTime($time);
        ok(-e $fileReq, "iTestCircuitRequest: circuit request has also been saved to a file");
    }

    # Test to see if the circuit has been established or not
    sub iTestCircuitEstablished {
        my $circuitManager = $_[ARG0];

        my $linkName = "T2_ANSE_CERN_1-to-T2_ANSE_CERN_2";
        my $circuit = $circuitManager->{CIRCUITS}{$linkName};

        is($circuit->{STATUS}, STATUS_ONLINE, "iTestCircuitEstablished: circuit status in circuit manager is correct");
        is($circuit->{NODE_A}, "T2_ANSE_CERN_1", "iTestCircuitEstablished: circuit established, validated NODE_A parameter");
        is($circuit->{NODE_B}, "T2_ANSE_CERN_2", "iTestCircuitEstablished: circuit established, validated NODE_B parameter");
        is($circuit->{IP_A}, "127.0.0.3", "iTestCircuitEstablished: circuit established, validated IP_A parameter");
        is($circuit->{IP_B}, "127.0.0.2", "iTestCircuitEstablished: circuit established, validated IP_B parameter");
        
        my $partialID = substr($circuit->{ID}, 1, 8);
        my $time = $circuit->{ESTABLISHED_TIME};
        my $fileReq = $baseLocation."/data/circuits/online/$linkName-$partialID-".formattedTime($time);
        ok(-e $fileReq, "iTestCircuitEstablished: established circuit has also been saved to a file");
    }
    
    # Request the circuit teardown
    sub iTeardownCircuit {
        my ($kernel, $session, $circuitManager) = @_[KERNEL, SESSION, ARG0];

        my $linkName = "T2_ANSE_CERN_1-to-T2_ANSE_CERN_2";
        my $circuit = $circuitManager->{CIRCUITS}{$linkName};

        $circuitManager->handleCircuitTeardown($kernel, $session, $circuit)
    };

    sub iTestTeardown {
        my $circuitManager = $_[ARG0];

        my $linkName = "T2_ANSE_CERN_1-to-T2_ANSE_CERN_2";
        my $circuitID = $circuitManager->{CIRCUITS_HISTORY}{$linkName};
        my $circuit = $circuitID->{(keys %{$circuitID})[0]};

        is($circuit->{STATUS}, STATUS_OFFLINE, "iTestTeardown: circuit status in circuit manager is correct");

        my $partialID = substr($circuit->{ID}, 1, 8);
        my $establishedtime = $circuit->{ESTABLISHED_TIME};
        my $offlinetime = $circuit->{LAST_STATUS_CHANGE};

        my $fileEstablished = $baseLocation."/data/circuits/online/$linkName-$partialID-".formattedTime($establishedtime);
        my $fileOffline = $baseLocation."/data/circuits/offline/$linkName-$partialID-".formattedTime($offlinetime);

        ok(!-e $fileEstablished, "iTestTeardown: online circuit has been removed");
        ok(-e $fileOffline, "iTestTeardown: offline circuit has been saved");
    }

    sub iStop {
        my $circuitManager = $_[ARG0];
        $circuitManager->stop();
    }

    my $mlParameters = {};

    my ($circuitManager, $session) = setupCircuitManager(22, 'ML.log', undef,
                                                        [[\&iRequestCircuit, 0.2],              # Request the circuit
                                                         [\&iTestCircuitRequest, 0.4],          # Test request
                                                         [\&iTestCircuitEstablished, 15],       # Test that the circuit was established
                                                         [\&iTeardownCircuit, 17],              # Request the teardown 
                                                         [\&iTestTeardown, 19],                 # Test teardown
                                                         [\&iStop, 21]],                        # Shutdown nicely
                                                        0,                                      # No HTTP Control
                                                        "ML",                                   # Use the ML Backend
                                                        $mlParameters);                         # Pass on parameters
                                                        
    $circuitManager->{BACKEND}{AGENT_TRANSLATION}{T2_ANSE_CERN_1} = "/";
    $circuitManager->{BACKEND}{AGENT_TRANSLATION}{T2_ANSE_CERN_2} = "/";
    
    $circuitManager->Logmsg('Testing the ML backend');

    ### Run POE
    POE::Kernel->run();
}

File::Path::rmtree("$baseLocation".'/logs', 1, 1) if (-d "$baseLocation".'/logs');
File::Path::make_path("$baseLocation".'/logs', { error => \my $err});

testMLBackend();

done_testing();


1;
