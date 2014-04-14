package PHEDEX::Tests::File::Download::HTTP::TestHTTPServer;

use warnings;
use strict;

# Normal imports
use POE;
use Test::More;

# PhEDEx imports
use PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpClient;
use PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpServer;

# Create master session
POE::Session->create(
        inline_states => {
            _start => sub {
                my ($kernel, $session) = @_[KERNEL, SESSION];

                # Create a http client and spawn it. It has been tested independently of this server
                # so we should be ok with using it these tests
                my $httpClient = PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpClient->new();
                $httpClient->spawn();

                # Setup the various tests that we need to do...
                $kernel->post($session, 'runGetMethodTests', $httpClient);
            },
            stopClient => sub {
                my ($kernel, $session, $httpClient, $httpServer) = @_[KERNEL, SESSION, ARG0, ARG1];

                # Stop the http client
                $httpClient->unspawn();

                # Stop the http server
                $httpServer->stopServer();
                $httpServer->resetHandlers();
            },

            runGetMethodTests   => \&runGetMethodTests,

            # Postback for the http client. It is called after it receives data from the server.
            # We use it to test the data that we get back
            httpClientPostback  => \&httpClientPostback,

            # This postback is created by a client which wants handle a given URL (/, /example, etc.)
            # It is linked to that URL via the addHandler method. This tells the HTTP Server that that
            # postback is to be called for a given combination of HTTP Request and URL (GET, "/")
            postbackForGetHandler  => \&postbackForGetHandler,
            postbackForPostHandler => \&postbackForPostHandler,
    });

sub runGetMethodTests {
    my ($kernel, $session, $httpClient) = @_[KERNEL, SESSION, ARG0];

    # Create the server
    my $httpServer = PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpServer->new();
    $httpServer->startServer("localhost", 8080);

    # Test data
    my $testData = {
        user            => "vlad",
        password        => "wouldn't you like to know",
        secretQuestion  => "Answer to the Ultimate Question of Life, the Universe, and Everything",
        secretAnswer    => 42
    };

    $httpServer->addHandler("GET", "/nodata", $session->postback("postbackForGetHandler"));
    $httpServer->addHandler("GET", "/", $session->postback("postbackForGetHandler", $testData));
    $httpServer->addHandler("GET", "/args", $session->postback("postbackForGetHandler", $testData, {'test' => 'result'}));

    $httpServer->addHandler("POST", "/post", $session->postback("postbackForPostHandler", $testData));

    # Test error handling
    $httpClient->httpRequest("GET", "http://localhost:8080/nodata", undef, $session->postback("httpClientPostback", undef, 500));               # Handler supplies an invalid object
    $httpClient->httpRequest("POST", "http://localhost:8080/nodata", undef, $session->postback("httpClientPostback", undef, 400));              # Handler doesn't exist for this method
    $httpClient->httpRequest("GET", "http://localhost:8080/invalidmethod", undef, $session->postback("httpClientPostback", undef, 400));        # Handler doesn't exist for this URI
    $httpClient->httpRequest("POST", "http://localhost:8080/post", ["TEXT", $testData], $session->postback("httpClientPostback", undef, 400));  # POSTed data was text

    # GET tests
    $httpClient->httpRequest("GET", "http://localhost:8080/", undef, $session->postback("httpClientPostback", $testData, 200));                     # OK
    $httpClient->httpRequest("GET", "http://localhost:8080/args", {'test' => 'result'}, $session->postback("httpClientPostback", $testData, 200));  # OK

    # POST tests
    $httpClient->httpRequest("POST", "http://localhost:8080/post", ["JSON", $testData], $session->postback("httpClientPostback", undef, 200));  # OK
    $httpClient->httpRequest("POST", "http://localhost:8080/post", ["FORM", $testData], $session->postback("httpClientPostback", undef, 200));  # OK

    $kernel->delay("stopClient" => 2, $httpClient, $httpServer); # stop everything after 2 seconds
}

sub postbackForGetHandler {
    my ($kernel, $session, $initialArgs, $postArgs) = @_[KERNEL, SESSION, ARG0, ARG1];

    my ($objectToProvide, $expectedArguments) = @{$initialArgs};
    my ($resultArguments, $resultCallback) = @{$postArgs};

    my $msg = "TestHTTPServer->postbackForGetHandler";
    is_deeply($resultArguments, $expectedArguments, "$msg: Resulted and expected arguments matched") if defined $expectedArguments;

    $resultCallback->($objectToProvide);
}

sub postbackForPostHandler {
     my ($kernel, $session, $initialArgs, $postArgs) = @_[KERNEL, SESSION, ARG0, ARG1];

    my ($expectedArguments) = @{$initialArgs};
    my ($resultArguments) = @{$postArgs};

    my $msg = "TestHTTPServer->postbackForPostHandler";
    is_deeply($resultArguments, $expectedArguments, "$msg: Resulted and expected arguments matched") if defined $expectedArguments;
}

sub httpClientPostback {
    my ($kernel, $session, $initialArgs, $postArgs) = @_[KERNEL, SESSION, ARG0, ARG1];

    my ($expectedObject, $expectedCode) = @{$initialArgs};
    my ($resultObject, $resultCode, $resultRequest) = @{$postArgs};

    my $uri = defined $resultRequest ? $resultRequest->{"_request"}->{"_uri"} : "unknown";

    my $msg = "TestHTTPServer->httpClientPostback";
    ok($postArgs, "$msg: ($uri) Arguments defined");

    is_deeply($resultObject, $expectedObject, "$msg: ($uri) Resulted and expected objects matched") if defined $expectedObject;
    is($resultCode, $expectedCode, "$msg: ($uri) Resulted and expected codes matched") if defined $expectedCode;

}

POE::Kernel->run();

done_testing;

1;