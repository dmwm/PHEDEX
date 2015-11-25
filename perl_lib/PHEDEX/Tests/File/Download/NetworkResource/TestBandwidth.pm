package PHEDEX::Tests::File::Download::NetworkResource::TestBandwidth;

use strict;
use warnings;

use File::Path;
use IO::File;
use Test::More;

use PHEDEX::File::Download::Circuits::Constants;
use PHEDEX::File::Download::Circuits::ManagedResource::Bandwidth;
use PHEDEX::File::Download::Circuits::ManagedResource::NetworkResource;

use PHEDEX::Tests::File::Download::Helpers::ObjectCreation;
use PHEDEX::Core::Timing;

# Trivial test consists of creating a circuit and making sure parameters are initialized correctly
sub testInitialisation {
    my $msg = "TestBandwidth->testInitialisation";
    
    # Create circuit and initialise it
    my $testBandwidth = PHEDEX::File::Download::Circuits::ManagedResource::Bandwidth->new();
    my $success = $testBandwidth->initResource("Dummy", "Node_A", "Node_B", 1);
    
    is($success, OK, "$msg: Object initialised successfully");
    ok($testBandwidth->{ID}, "$msg: ID set");
    is($testBandwidth->{NODE_A}, 'Node_A', "$msg: Object initialisation - Node_A set");
    is($testBandwidth->{NODE_B}, 'Node_B', "$msg: Object initialisation - Node_B set");
    is($testBandwidth->{BOOKING_BACKEND}, 'Dummy', "$msg: Object initialisation - Backend set");
    is($testBandwidth->{STATUS}, STATUS_OFFLINE, "$msg: Object initialisation - Status set to offline");
    is($testBandwidth->{STATE_DIR}, '/tmp/managed/bod', "$msg: Object initialisation - Correct state folder set");
    is($testBandwidth->{BANDWIDTH_STEP}, 1, "$msg: Object initialisation - Bandwidth step set");
    is($testBandwidth->{BANDWIDTH_MIN}, 0, "$msg: Object initialisation - Min bandwidth set");
    is($testBandwidth->{BANDWIDTH_MAX}, 1000, "$msg: Object initialisation - Max bandwidth set");
    is($testBandwidth->{BANDWIDTH_ALLOCATED}, 0, "$msg: Object initialisation - Allocated bandwidth set");
}

# Testing the getExpirationTime, isExpired and getLinkName subroutines
sub testHelperMethods {
    my $msg = "TestBandwidth->testHelperMethods";
    
    my $bandwidth1 = createOfflineBandwidth();
    my $bandwidth2 = createUpdatingBandwidth();
    my $bandwidth3 = createRunningBandwidth();

    is($bandwidth1->{NAME}, 'T2_ANSE_GENEVA-to-T2_ANSE_AMSTERDAM', "$msg: Name was set correctly");

    # Test getSavePaths
    ok($bandwidth1->getSavePaths() =~ /offline/, "$msg: getSavePaths works as it should on an offline bandwidth");
    ok($bandwidth2->getSavePaths() =~ /offline/, "$msg: getSavePaths works as it should on an updating bandwidth");
    ok($bandwidth3->getSavePaths() =~ /online/, "$msg: getSavePaths works as it should on a running bandwidth");
    
    # Test validateBandwidth
    is($bandwidth3->validateBandwidth(501.2), ERROR_GENERIC, "$msg: validateBandwidth rejects value not a multiple of step size");
    is($bandwidth3->validateBandwidth(1001), ERROR_GENERIC, "$msg: validateBandwidth rejects value over max");
    is($bandwidth3->validateBandwidth(-1), ERROR_GENERIC, "$msg: validateBandwidth rejects value under min");
}

# Testing changing of status of the bandwidth object
sub testStatusChange {
    my $msg = "TestBandwidth->testStatusChange";
    
    my ($offlineBW, $runningBW, $updatingBW);
    
    # Checking registerUpdateRequest
    $offlineBW = createOfflineBandwidth();
    $runningBW = createRunningBandwidth();
    $updatingBW = createUpdatingBandwidth();
   
    is($updatingBW->registerUpdateRequest(1000), ERROR_GENERIC, "$msg: failed to register update on updating bw");
    is($offlineBW->registerUpdateRequest(1000), OK, "$msg: registered update request on an offline bw");
    is($runningBW->registerUpdateRequest(1000), OK, "$msg: registered update request on an online bw");
    
    is($offlineBW->{STATUS}, STATUS_UPDATING, "$msg: updating object status is ok");
    is($offlineBW->{BANDWIDTH_ALLOCATED}, 0, "$msg: updating object allocated bw is 0");
    is($offlineBW->{BANDWIDTH_REQUESTED}, 1000, "$msg: updating object requested bw is 500");
    
    is($runningBW->{STATUS}, STATUS_UPDATING, "$msg: updating object status is ok");
    is($runningBW->{BANDWIDTH_ALLOCATED}, 500, "$msg: updating object allocated bw is 0");
    is($runningBW->{BANDWIDTH_REQUESTED}, 1000, "$msg: updating object requested bw is undef");
    
    # Checking registerUpdateFailed
    $offlineBW = createOfflineBandwidth();
    $runningBW = createRunningBandwidth();
    $updatingBW = createUpdatingBandwidth();
    
    is($offlineBW->registerUpdateFailed(), ERROR_GENERIC, "$msg: cannot register a failed update on an offline bw");
    is($runningBW->registerUpdateFailed(), ERROR_GENERIC, "$msg: cannot register a failed update on an online bw");
    
    is($updatingBW->{STATUS}, STATUS_UPDATING, "$msg: updating object status is ok");
    is($updatingBW->{BANDWIDTH_ALLOCATED}, 0, "$msg: updating object allocated bw is 0");
    is($updatingBW->{BANDWIDTH_REQUESTED}, 500, "$msg: updating object requested bw is 500");
    
    is($updatingBW->registerUpdateFailed(), OK, "$msg: registered update failure on updating bw");
    is($updatingBW->{STATUS}, STATUS_OFFLINE, "$msg: updating object status is ok");
    is($updatingBW->{BANDWIDTH_ALLOCATED}, 0, "$msg: updating object allocated bw is 0");
    is($updatingBW->{BANDWIDTH_REQUESTED}, undef, "$msg: updating object requested bw is undef");

    # Checking registerUpdateSuccessful
    $offlineBW = createOfflineBandwidth();
    $runningBW = createRunningBandwidth();
    $updatingBW = createUpdatingBandwidth();

    is($offlineBW->registerUpdateSuccessful(), ERROR_GENERIC, "$msg: cannot register a successful update on an offline bw");
    is($runningBW->registerUpdateSuccessful(), ERROR_GENERIC, "$msg: cannot register a successful update on an online bw");
    
    is($updatingBW->{STATUS}, STATUS_UPDATING, "$msg: updating object status is ok");
    is($updatingBW->{BANDWIDTH_ALLOCATED}, 0, "$msg: updating object allocated bw is 0");
    is($updatingBW->{BANDWIDTH_REQUESTED}, 500, "$msg: updating object requested bw is 500");
    
    is($updatingBW->registerUpdateSuccessful(), OK, "$msg: registered update success on updating bw");
    is($updatingBW->{STATUS}, STATUS_ONLINE, "$msg: updating object status is ok");
    is($updatingBW->{BANDWIDTH_ALLOCATED}, 500, "$msg: updating object allocated bw is 500");
    is($updatingBW->{BANDWIDTH_REQUESTED}, undef, "$msg: updating object requested bw is undef");
}

# TODO: Test save/open/remove (although circuit tests show that it's fine...)
testInitialisation();
testHelperMethods();
testStatusChange();

done_testing();

1;
