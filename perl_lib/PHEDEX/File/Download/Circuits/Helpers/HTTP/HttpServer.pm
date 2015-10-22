package PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpServer;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';

use CGI;
use HTTP::Response;
use HTTP::Status qw(:constants);
use JSON::XS;
use POE qw(Component::Server::TCP Filter::HTTPD);
use Switch;

use PHEDEX::File::Download::Circuits::Helpers::HTTP::HttpConstants;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
        ALIAS               => "phedex_json_server",
        HOSTNAME            => 'vlad-vm-slc6.cern.ch',
        PORT                => 8080,
        SERVER_SESSION_ID   => undef,
        ACTIONS             => {}
    );

    my %args = (@_);

    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    bless $self, $class;
    return $self;
}

# Starts a WEB server (using POE::Component::Server::TCP)
sub startServer {
    my ($self, $hostname, $port, $timeout) = @_;

    # This server should behave as a singleton, so lets check that one
    # is not already started before we continue here
    if (defined $self->{SERVER_SESSION_ID}) {
        $self->Logmsg("Cannot start a new HTTP server. Please stop the current server before you attempt to start another one");
        return HTTP_SERVER_ALREADY_STARTED;
    }

    # Replace any default parameters if they have been specified
    $self->{HOSTNAME} = $hostname if defined $hostname;
    $self->{PORT} = $port if defined $port;
    $self->{REPLY_TIMEOUT} = $timeout if defined $timeout;

    $self->Logmsg("Starting HTTP server: $self->{HOSTNAME}:$self->{PORT}");

    $self->{SERVER_SESSION_ID} =
        POE::Component::Server::TCP->new(
            Alias           => $self->{ALIAS},
            Hostname        => $self->{HOSTNAME},
            Port            => $self->{PORT},
            ClientFilter    => 'POE::Filter::HTTPD',
            InlineStates    => {
                # Declare the event for the postback which will be handed to the
                # handler of a given action. When the server receives a GET request
                # a postback will be created and handed to the action handler of that request.
                # When it has the data which was requested, the handler will call this postback
                # handing it to the HTTP server. The server will then create an HTTP Response
                # with the data provided by the handler.
                returnData  =>  \&returnData,
            },
            ClientInput     => sub {
                my ($kernel, $heap, $session, $request) = @_[KERNEL, HEAP, SESSION, ARG0];

                # Filter::HTTPD sometimes generates HTTP::Response objects.
                # They indicate (and contain the response for) errors that occur
                # while parsing the client's HTTP request.  It's easiest to send
                # the responses as they are and finish up.
                if ($request->isa("HTTP::Response")) {
                    $heap->{client}->put($request);
                    $kernel->yield("shutdown");
                    return;
                }

                # The request is real and fully formed.
                # Check to see if we have any postbacks defined for the current URI
                my $method = $request->method();
                my $uri = $request->uri();
                $uri =~ s/\?.*//;

                my $action = $self->{ACTIONS}{$method}{$uri};

                if (!defined $action) {
                    my $errorMessage = "This URI ($uri) has no action specified for the method used ($method)";
                    $self->Logmsg($errorMessage);
                    sendHttpReply($kernel, $heap, HTTP_BAD_REQUEST, "text/html", $errorMessage);
                    return;
                }

                switch($method) {
                    case 'POST' {
                        $self->handlePostRequest($kernel, $heap, $request, $action);
                    }
                    case 'GET' {
                        $self->handleGetRequest($kernel, $session, $heap, $request, $action);
                    }
                }
            },
        );
}

# Stops the server
# TODO: Check how this call behaves when we're in the process of replying to someone...
sub stopServer {
    my $self = shift;

    if (! defined $self->{SERVER_SESSION_ID}) {
        $self->Logmsg("Cannot shutdown if the server is not started yet");
        return HTTP_SERVER_NOT_STARTED;
    }

    $self->Logmsg("HttpServer->stop: Shutting down HTTP Server");
    POE::Kernel->post($self->{SERVER_SESSION_ID}, 'shutdown');
    delete $self->{SERVER_SESSION_ID};
}

# This method handles POST requests encoded as x-www-form-urlencoded or json data
# We only allow POST requests when *updating* the data
# Once the arguments have been retrieved, the action (postback) will be called with
# these parameters and a reply will be sent (HTTP_OK)
sub handlePostRequest {
    my ($self, $kernel, $heap, $request, $action) = @_;

    my $mess = "HttpServer->handlePostRequest";

    # Check that we have a valid request object
    if (!defined $request) {
        $self->Logmsg("$mess : invalid request object has been provided");
        return HTTP_SERVER_REQUEST_INVALID;
    }

    # Check that we can handle the content that's going to come in
    # We currently only allow FORM data or JSON objects
    my $contentType = $request->headers()->{'content-type'};
    my $postArguments;

    # Retrieve the arguments which were passed in the request
    switch ($contentType) {
        case "application/x-www-form-urlencoded" {
            $postArguments = CGI->new($request->content)->Vars();
        }
        case "application/json" {
            my $encodedJson = $request->content;
            # TODO: Do some sort of validation to check if this is
            # actually JSON content or else the conversion will fail with a croak
            $postArguments = decode_json($encodedJson);
        }
        else {
            my $errorMessage = "Can only handle input from FORM data or JSON objects passed in content";
            $self->Logmsg($mess.": ".$errorMessage);
            sendHttpReply($kernel, $heap, HTTP_BAD_REQUEST, "text/html", $errorMessage);
            return HTTP_SERVER_REQUEST_INVALID_FORMAT;
        }
    }

    # Since post is used for updating data, there have to be arguments passed for us to process...
    # If that's not the case, inform via an Error message
    if (!defined $postArguments) {
        my $errorMessage = "No arguments passed via POST method. Request will be ignored";
        $self->Logmsg($mess.": ".$errorMessage);
        sendHttpReply($kernel, $heap, HTTP_BAD_REQUEST, "text/html", $errorMessage);
        return HTTP_SERVER_REQUEST_NO_ARGS;
    }

    # If we get to here it means that we have valid arguments which were passed via POST
    # All that remains now is to:

    # Reply saying we'll handle it
    # TODO: Implement a callback mechanism which only sends a reply *after* the update has been done
    sendHttpReply($kernel, $heap, HTTP_OK, "text/html, application/json", "{\"Status\":\"OK\"}");

    # Call the action which will handle the update internally
    $action->($postArguments);
}

# This method handles GET requests. We can only send back json objects as replies (application/json)
# We only allow GET methods to retrieve data (no updating).
# This class is not the one that's getting the data. We first need to call the action associated
# with the URI requested, then when results are back, reply to the client.
# To do this, we produce a postback here, which is passed as argument when calling the action
# The client must call this postback in order to reply to the client with the required data
sub handleGetRequest {
    my ($self, $kernel, $session, $heap, $request, $action) = @_;

    my $mess = "HttpServer->handleGetRequest";

    # Check that we have a valid request object
    if (!defined $request) {
        $self->Logmsg("$mess : invalid request object has been provided");
        return HTTP_SERVER_REQUEST_INVALID;
    }

    # Check that we can send the type of objects which are accepted by the client
    my $contentType = $request->headers()->{'accept'};

    if (! $contentType =~ "application/json") {
        my $errorMessage = "We can only reply with JSON objects";
        $self->Logmsg($mess.": ".$errorMessage);
        # Paradoxically, we're sending this^ as text :)
        sendHttpReply($kernel, $heap, HTTP_BAD_REQUEST, "text/html", $errorMessage);
        return HTTP_SERVER_REQUEST_INVALID_FORMAT;
    }

    # GET needs a bit more work on our part, since we need to actually give data back to the client
    my $getArguments = CGI->new($request->url->query)->Vars();

    # Create a postback. This will be used by the client to pass data back to the HTTPServer.
    my $callMeBack= $session->postback('returnData', $heap);

    # Call the action, while specifing the GET arguments and the postback method
    $action->($getArguments, $callMeBack);
}

# This server won't process any URIs unless a handler is added.
# The idea is that for a given HTTP method (POST/GET) and for a given URI (/, /example, /example2),
# we associate a postback which was generated by the entity which wants to process that URI
# Ex: a POST to [web address]/updatePath will call a postback generated by the CircuitManager
sub addHandler {
    my ($self, $type, $action, $callback, $force) = @_;

    if (!defined $action || !defined $callback ||
        ($type ne 'GET' && $type ne 'POST')) {
        $self->Logmsg("The specified parameters were invalid. Cannot add action");
        return HTTP_SERVER_HANDLER_INVALID_PARAMS;
    }

    if (substr($action, 0, 1) ne "/") {
        $self->Logmsg("Action should begin with a /");
        return HTTP_SERVER_HANDLER_INVALID_URI;
    }

    if (defined $self->{ACTIONS}{$type}{$action} && !$force) {
        $self->Logmsg("There is already an action specified. Skipping update");
        return HTTP_SERVER_HANDLER_ALREADY_EXISTS;
    }

    if (defined $self->{ACTIONS}{$type}{$action} && $force) {
        # TODO: This server might be needed by multiple instances, change accordingly
        $self->Logmsg("You have just overridden a previous action");
    }

    $self->{ACTIONS}{$type}{$action} = $callback;
}

# Removes a handler from our list
sub removeHandler {
    my ($self, $type, $action) = @_;

    if (! defined $type || ! defined $action) {
        $self->Logmsg("HttpServer->removeHandler : invalid parameters passed to method");
        return HTTP_SERVER_HANDLER_INVALID_PARAMS;
    }

    if (! defined $self->{ACTIONS}{$type} || $self->{ACTIONS}{$type}{$action}) {
        $self->Logmsg("HttpServer->removeHandler : cannot find the specified hash parameters");
        return HTTP_SERVER_HANDLER_NOT_FOUND;
    }

    delete $self->{ACTIONS}{$type}{$action};
}

# Removes *all* the handlers which were defined until now
sub resetHandlers {
    my $self = shift;
    $self->Logmsg("HttpServer->resetHandlers: removing all handles for this http server!");
    delete $self->{ACTIONS};
}

# A postback will be created and handed to a client whenever someone requests data (via GET)
# The client will call this postback with the PERL object that it wants to send.
# This object will then be encoded in JSON and sent back to the requestor
sub returnData {
    my ($kernel, $session, $initialArgs, $passedArgs) = @_[KERNEL, SESSION, ARG0, ARG1];

    my $heap = $initialArgs->[0];
    my $replyObject = $passedArgs->[0];

    if (! defined $replyObject) {
        sendHttpReply->($kernel, $heap, HTTP_INTERNAL_SERVER_ERROR, "text/html", "Cannot provide the content requested. Request was forwarded to a handler, but no object was received in return");
        return;
    }
    

    my $jsonObject = JSON::XS->new->convert_blessed->encode($replyObject);
    sendHttpReply->($kernel, $heap, HTTP_OK, "application/json", $jsonObject);
}


sub sendHttpReply {
    my ($kernel, $heap, $status, $contentType, $message) = @_;
    my $response = HTTP::Response->new($status);
    $response->push_header('Content-type', $contentType);
    $response->content($message);
    $heap->{client}->put($response);
    $kernel->yield("shutdown");
}

1;
