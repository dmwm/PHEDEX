package PHEDEX::Tests::File::Download::NetworkResource::TestNetworkResource;

use strict;
use warnings;

use IO::File;
use Test::More;

use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::File::Download::Circuits::Helpers::GenericFunctions;
use PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource;


# Test the "getPath" function - used to return the link name 
sub testHelperMethods {
    my $msg = "TestNetworkResource->testHelperMethods";
    
    my $wrongPath1 = getPath(undef, "NodeB");
    is($wrongPath1, undef, "$msg: Get path cannot return path with one of the nodes undef");
    my $wrongPath2 = getPath("NodeA", undef);
    is($wrongPath2, undef, "$msg: Get path cannot return path with one of the nodes undef");
    
    my $path1 = getPath("NodeA", "NodeB", 0);
    is($path1, "NodeA-to-NodeB", "$msg: Get path correctly returns path for bidirectional path");
    my $path2 = getPath("NodeA", "NodeB", 1);
    is($path2, "NodeA-NodeB", "$msg: Get path correctly returns path for unidirectional path");
    my $path3 = getPath("NodeA", "NodeB", undef);
    is($path3, "NodeA-to-NodeB", "$msg: Get path correctly returns path with default values");
}

# Self explaining test
sub testInitialisation {
    my $msg = "TestNetworkResource->testInitialisation";
    
    my $resource = PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource->new();
    
    # Attempt to initialise a resource with wrong parameters
    my $success = $resource->initResource(undef, "BOD", "Node_A", "Node_B", "Directionality");
    is($success, ERROR_GENERIC, "$msg: Cannot initialise (backend undef)");
    $success = $resource->initResource("Dummy", undef, "Node_A", "Node_B", "Directionality");
    is($success, ERROR_GENERIC, "$msg: Cannot initialise (type undef)");
    $success = $resource->initResource("Dummy", "BOD", undef, "Node_B", "Directionality");
    is($success, ERROR_GENERIC, "$msg: Cannot initialise (NodeA undef)");
    $success = $resource->initResource("Dummy", "BOD", "Node_A", undef, "Directionality");
    is($success, ERROR_GENERIC, "$msg: Cannot initialise (NodeB undef)");
    
    # Provide all the correct parameters to the initialisation and test to see if they were all set in the object
    $success = $resource->initResource("Dummy", "BOD", "Node_A", "Node_B", "Directionality");
    is($success, OK, "$msg: Correctly initialised a resource");
    is($resource->{BOOKING_BACKEND}, "Dummy", "$msg: Initialisation ok (backend matches)");
    is($resource->{RESOURCE_TYPE}, "BOD", "$msg: Initialisation ok (type matches)");
    is($resource->{NODE_A}, "Node_A", "$msg: Initialisation ok (NodeA matches)");
    is($resource->{NODE_B}, "Node_B", "$msg: Initialisation ok (NodeB matches)");
    is($resource->{BIDIRECTIONAL}, 1, "$msg: Initialisation ok (BIDIRECTIONAL matches)");
    is($resource->{NAME}, "Node_A-Node_B", "$msg: Initialisation ok (path name matches)");
    is($resource->{SCOPE}, "GENERIC", "$msg: Initialisation ok (scope matches)");
    ok($resource->{LAST_STATUS_CHANGE}, "$msg: Initialisation ok (remembered last status change)");
}

sub testComparison {
    my $msg = "TestNetworkResource->testComparison";

    my $resource1 = PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource->new();
    $resource1->initResource("Dummy", "BOD", "Node_A", "Node_B", 1);

    my $resource2 = PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource->new();
    $resource2->initResource("Dummy", "BOD", "Node_A", "Node_B", 1);
    $resource2->{ID} = $resource1->{ID};
    $resource2->{LAST_STATUS_CHANGE} = $resource1->{LAST_STATUS_CHANGE};

    my $resource3 = PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource->new();
    $resource3->initResource("Dummy", "BOD", "Node_B", "Node_A", 1);

    ok(!compareResource($resource1, undef), "$msg: Comparison with undef failed");
    ok(compareResource($resource1, $resource1), "$msg: Comparison with self went ok");
    ok(compareResource($resource1, $resource2), "$msg: Comparison with identical object went ok");
    ok(!compareResource($resource1, $resource3), "$msg: Comparison with almost identical object failed (ID different)");
}

# Trivial test consisting of trying to open invalid circuits
sub testOpenErrorHandling {
    my $msg = "TestNetworkResource->testOpenErrorHandling";
    is(PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource->openState(undef), ERROR_OPENING, "$msg: Unable to open since path is not defined");    
    is(PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource->openState('/tmp/bla.resource'), ERROR_OPENING, "$msg: Unable to open since the path is invalid");
    
    # Create a "bad"/"malformed" resource
    my $fh = new IO::File "/tmp/bla.resource";
    if (defined $fh) {
        print $fh "This is malformed file\n";
        $fh->close();
    }
    is(PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource->openState('/tmp/bla.resource'), ERROR_OPENING, "$msg: Unable to open an invalid resource");
}

testHelperMethods();
testInitialisation();
testComparison();
testOpenErrorHandling();

done_testing();

1;
