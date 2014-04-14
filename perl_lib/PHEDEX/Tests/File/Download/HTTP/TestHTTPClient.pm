package PHEDEX::Tests::File::Download::HTTP::TestHTTPClient;

use warnings;
use strict;

use JSON::XS;
use POE;
use PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpClient;
use PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpConstants;
use Test::More;

# Create master session
POE::Session->create(
        inline_states => {
            _start => sub {
                my ($kernel, $session) = @_[KERNEL, SESSION];

                # Create a user agent and spawn it
                my $userAgent = PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpClient->new();
                $userAgent->spawn();

                # Setup the various tests that we need to do...
                $kernel->post($session, 'runGetMethodTests', $userAgent);
                $kernel->post($session, 'runPostMethodTests', $userAgent);
            },
            stopClient => sub {
                my ($kernel, $session, $userAgent) = @_[KERNEL, SESSION, ARG0];
                $userAgent->unspawn();
            },

            runGetMethodTests   => \&runGetMethodTests,
            runPostMethodTests  => \&runPostMethodTests,

            # Postback used to test replies
            validateHttpRequest => \&validateHttpRequest,
    });

sub runGetMethodTests {
    my ($kernel, $session, $userAgent) = @_[KERNEL, SESSION, ARG0];

    # Test error handling
    $userAgent->httpRequest("GET", "http://this.site.does.not.exist.com/", undef, $session->postback("validateHttpRequest", undef, 500));# Site doesn't exist
    $userAgent->httpRequest("GET", "http://www.google.com/", undef, $session->postback("validateHttpRequest", undef, 302));              # Site replies with "Found" (considered as error)
    $userAgent->httpRequest("GET", "http://www.youtube.com/", undef, $session->postback("validateHttpRequest", undef, 415));             # Site replies with something, but it's not JSON

    # Test with sources providing valid json objects
    $userAgent->httpRequest("GET", "http://ip.jsontest.com/", undef, $session->postback("validateHttpRequest"));
    $userAgent->httpRequest("GET", "http://date.jsontest.com/", undef, $session->postback("validateHttpRequest"));

    # Test one of the objects that we get back from the server
    my $headers = {
        'Host'          => 'headers.jsontest.com',
        'User-Agent'    => 'POE-Component-Client-HTTP/0.949 (perl; N; POE; en; rv:0.949000)'
    };
    $userAgent->httpRequest("GET", "http://headers.jsontest.com/", undef, $session->postback("validateHttpRequest", $headers, 200));

    # Test get method with url encoded data provided
    my $input = { text  => "This text was passed as form data" };
    my $echo = {
        md5         => 'f17f1627580f66f8af8d712d52318bb6',
        original    => "This text was passed as form data"
    };

    $userAgent->httpRequest("GET", "http://md5.jsontest.com/", $input, $session->postback("validateHttpRequest", $echo, 200));

    # Test with another site
    $userAgent->httpRequest("GET", "http://httpbin.org/get", undef, $session->postback("validateHttpRequest", undef, 200));
}

sub runPostMethodTests {
    my ($kernel, $session, $userAgent) = @_[KERNEL, SESSION, ARG0];

    # Test data
    my $testData = {
        user            => "vlad",
        password        => "wouldn't you like to know",
        secretQuestion  => "Answer to the Ultimate Question of Life, the Universe, and Everything",
        secretAnswer    => 42
    };

    # Test error handling
    $userAgent->httpRequest("POST", "http://this.site.does.not.exist.com/", ["FORM", $testData], $session->postback("validateHttpRequest", undef, 500));# Site doesn't exist
    $userAgent->httpRequest("POST", "http://httpbin.org/get", ["FORM", $testData], $session->postback("validateHttpRequest", undef, 405));              # Method not allowed

    # Test posting of data
    $userAgent->httpRequest("POST", "http://httpbin.org/post", ["FORM", $testData], $session->postback("validateHttpRequest", $testData, 200, "form"));
    $userAgent->httpRequest("POST", "http://httpbin.org/post", ["JSON", $testData], $session->postback("validateHttpRequest", $testData, 200, "json"));
    $userAgent->httpRequest("POST", "http://httpbin.org/post", ["TEXT", $testData], $session->postback("validateHttpRequest", undef, 200));
    $userAgent->httpRequest("POST", "http://httpbin.org/post", ["BLA", $testData], $session->postback("validateHttpRequest", undef, HTTP_CLIENT_INVALID_REQUEST));
}

sub validateHttpRequest {
    my ($kernel, $session, $initialArgs, $postArgs) = @_[KERNEL, SESSION, ARG0, ARG1];
    my ($expectedObject, $expectedCode, $subObject) = @{$initialArgs};
    my ($resultObject, $resultCode, $resultRequest) = @{$postArgs};

    # In the case of httpbin, we want to check a sub-element of the data which was sent by the server
    $resultObject = $resultObject->{$subObject} if defined $subObject;

    my $uri = defined $resultRequest ? $resultRequest->{"_request"}->{"_uri"} : "unknown";

    my $msg = "TestHTTPClient->validateHttpRequest";
    ok($postArgs, "$msg: ($uri) Arguments defined");

    is_deeply($resultObject, $expectedObject, "$msg: ($uri) Resulted and expected objects matched") if defined $expectedObject;
    is($resultCode, $expectedCode, "$msg: ($uri) Resulted and expected codes matched") if defined $expectedCode;
}


POE::Kernel->run();

done_testing;

1;