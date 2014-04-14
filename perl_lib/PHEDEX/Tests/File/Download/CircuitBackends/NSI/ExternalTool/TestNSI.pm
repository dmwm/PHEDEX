package PHEDEX::Tests::File::Download::CircuitBackends::NSI::ExternalTool::TestNSI;

use strict;
use warnings;

use PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::NSI;
use PHEDEX::File::Download::Circuits::ManagedResource::Circuit;

use POE;
use Switch;
use Test::More;

sub setupSession {
    my $nsiBackend = shift;
    
    my $states;

    $states->{_start} = sub {
        my ($kernel, $session) = @_[KERNEL, SESSION];
        $nsiBackend->Logmsg("Starting a POE test session (id=",$session->ID,")");
        $nsiBackend->_poe_init($kernel, $session);
        
        my $testCircuit = PHEDEX::File::Download::Circuits::ManagedResource::Circuit->new();
        $testCircuit->initResource("Dummy", 
                                   "NODE_A", 
                                   "NODE_B", 
                                   1);
        
        # Delayed request of a circuit
        $kernel->delay(backendRequestCircuit => 7, $testCircuit, $session);
    };
    
    $states->{stopSession} = sub {
        my $eventCount = POE::Kernel->get_event_count();
        print "There are still $eventCount events queued\n";
        POE::Kernel->stop();
    };
    
    $states->{delayedPosting} = \&delayedPosting;

    my $session = POE::Session->create(inline_states => $states);

    return $session;
}

my $nsiBackend = PHEDEX::File::Download::Circuits::Backend::NSI::ExternalTool::NSI->new();
my $session = setupSession($nsiBackend);

### Run POE
POE::Kernel->run();


done_testing;

1;