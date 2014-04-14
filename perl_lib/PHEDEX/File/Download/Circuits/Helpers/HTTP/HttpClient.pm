package PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpClient;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';

use JSON::XS;
use HTTP::Request;
use HTTP::Request::Common;
use HTTP::Status qw(:constants);
use POE::Component::Client::HTTP;
use POE;
use Switch;

use PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpConstants;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
        USER_AGENT_ALIAS    => 'poeHttpClient',
        USER_AGENT_TIMEOUT  => 1,
        SPAWNED             => 0,
    );

    my %args = (@_);

    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    bless $self, $class;
    return $self;
}

# Starts the client
# The client will keep connections alive for more 15 seconds, in case multiple requests will be made to the same address
sub spawn {
    my $self = shift;

    my $msg = "HttpClient->spawn";
    if ($self->{SPAWNED} == 1) {
        $self->Logmsg("$msg: Cannot (won't) spawn another instance of the HTTP Client. Please use the current one...");
        return;
    }

    # Create a user agent which will be referred as "poe_http_client" (default).
    POE::Component::Client::HTTP->spawn(
        Alias   => $self->{USER_AGENT_ALIAS},
        Timeout => $self->{USER_AGENT_TIMEOUT},
    );

    $self->{SPAWNED} = 1;
}

# Calls the client's 'shutdown' state which in turn, responds to all pending requests with
# 408 (request timeout), and then shuts down the component and all subcomponents
sub unspawn {
    my $self = shift;

    my $msg = "HttpClient->spawn";
    if ($self->{SPAWNED} == 0) {
        $self->Logmsg("$msg: There is no HTTP Client which is currently spawned");
        return;
    }

    $self->Logmsg("$msg: Unspawning client");
    $poe_kernel->post($self->{USER_AGENT_ALIAS}, "shutdown");
    $self->{SPAWNED} = 0;
}

# HTTP GET: only used to retrieve data from the URL. Arguments can be specified
# These arguments however need to be specified as hashes
sub httpRequest {
    my ($self, $requestType, $url, $requestArguments, $replyPostback) = @_;

    my $msg = "HttpClient->httpRequest";

    if ($self->{SPAWNED} == 0) {
        $self->Logmsg("$msg: There is no HTTP Client which is currently spawned");
        return HTTP_CLIENT_NOT_SPAWNED;
    }

    if (!defined $url || !defined $replyPostback) {
        $self->Logmsg("$msg: Invalid parameters were specified");
        return HTTP_CLIENT_INVALID_PARAMS;
    }

    # Create a session for this request (one session = one request)
    POE::Session->create(
        inline_states => {
            _start => sub {
                my ($kernel, $session) = @_[KERNEL, SESSION];
                switch($requestType) {
                    case "GET" {
                        if (defined $requestArguments && ref $requestArguments ne ref {}) {
                             $self->Logmsg("$msg: Arguments were specified, but we need them in hash form");
                            return HTTP_CLIENT_INVALID_PARAMS;
                        }
                        $kernel->post($session, "httpGetRequest", $requestArguments);
                    }
                    case "POST" {
                        if (ref $requestArguments ne ref []) {
                             $self->Logmsg("$msg: Arguments were specified, but we need them in array form");
                            return HTTP_CLIENT_INVALID_PARAMS;
                        }
                        my ($contentType, $content) = @{$requestArguments};
                        $kernel->post($session, "httpPostRequest", $contentType, $content);
                    }
                    else {
                        $self->Logmsg("$msg: Other requests types are unsupported for now");
                        return HTTP_CLIENT_INVALID_REQUEST;
                    }
                }
            },

            httpGetRequest  => sub {
                my ($kernel, $arguments) = @_[KERNEL, ARG0];

                # GET method, so we need to encode the arguments in the URL itself
                my $urlEncoded = URI->new($url);
                $urlEncoded->query_form($arguments) if defined $arguments;

                # Create HTTP GET request with arguments in form data
                my $request = HTTP::Request->new(GET => $urlEncoded);

                # Submit request
                $kernel->post($self->{USER_AGENT_ALIAS}, "request", "gotResponse", $request);
            },

            httpPostRequest => sub {
                my ($kernel, $contentType, $content) = @_[KERNEL, ARG0, ARG1];

                my $request;

                switch($contentType) {
                    case 'FORM' {
                        if (ref $content ne ref {}) {
                             $self->Logmsg("$msg: We need a hash ref when sending FORM encoded data");
                            return;
                        }
                        $request = POST "$url", $content;
                    }
                    case 'JSON' {
                        $request = HTTP::Request->new(POST => $url);
                        $request->header('content-type' => 'application/json');
                        my $jsonObject = JSON::XS->new->convert_blessed->encode($content);
                        $request->content($jsonObject);
                    }
                    case 'TEXT' {
                        $request = HTTP::Request->new(POST => $url);
                        $request->header('content-type' => 'text/html');
                        $request->content($content);
                    }
                    else {
                        $self->Logmsg("$msg: Don't know how to encode the data that you want to send as the content type that you specified ($contentType)");
                        $replyPostback->(undef, HTTP_CLIENT_INVALID_REQUEST, undef);
                        return;
                    }
                }

                $kernel->post($self->{USER_AGENT_ALIAS} => request => gotResponse => $request);
            },

            gotResponse => sub {
                my ($heap, $request, $response) = @_[HEAP, ARG0, ARG1];

                my $httpResponse = $response->[0];
                my $code = $httpResponse->code();

                if (!$self->replyOk($httpResponse)) {
                    $replyPostback->(undef, $code, $httpResponse);
                    return;
                };

                my $contentTypes = $httpResponse->headers()->{'content-type'};

                # TODO: Allow for the server to send OKs in something other than JSON after requests via POST
                if ($contentTypes !~ 'application/json') {
                    $self->Logmsg("$msg: We received a valid response, but we cannot process its content ($contentTypes). We currently only support 'application/json'");
                    $replyPostback->(undef, HTTP_UNSUPPORTED_MEDIA_TYPE, $httpResponse);
                    return;
                }

                my $json_content = $httpResponse->decoded_content;

                # TODO: Need to validate content before attempting to decode as json...
                my $decoded_json = decode_json($json_content);

                $replyPostback->($decoded_json, $code, $httpResponse);
            }
        }
    );
}

sub replyOk {
    my ($self, $httpResponse) = @_;

    # Check to see if request was successfull
    if (! $httpResponse->is_success) {
        my $code = $httpResponse->code;
        my $message = $httpResponse->message;
        $self->Logmsg("HttpClient->replyOk: an error has occured (CODE: $code, MESSAGE: $message)");
        return 0;
    }

    return 1;
}

1;