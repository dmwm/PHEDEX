package PHEDEX::Testbed::ModPerl::Examples;
  
use strict;
use warnings;
  
use Apache2::RequestRec ();
use Apache2::RequestIO ();
  
# :http defines most HTTP status codes
use Apache2::Const -compile => qw(OK NOT_FOUND :http);

# lookup an example function to call, call it
sub handler {
    my $r = shift;

    my $uri = $r->uri();           # get the URI
    my @path = split (/\//, $uri); # split the path
    my $func = pop @path;          # our function is the last item

    # check to see if function exists.  If so, call it
    no strict 'refs';
    if (exists ${"PHEDEX::Testbed::ModPerl::Examples\::"}{$func}) {
	return &{${"PHEDEX::Testbed::ModPerl::Examples\::"}{$func}}($r);
    }
    else {
	return Apache2::Const::NOT_FOUND; # 404
    }
}

# simple "hello world"
sub hello {
    my $r = shift;
    $r->content_type('text/plain');
    print "Hello World!\n";
    return Apache2::Const::OK;
}

# HTTP 400 bad request
sub bad {
    return Apache2::Const::HTTP_BAD_REQUEST;
}

# Example of long output.  Does the response header get set to 200
# regardless of the 'return' value?
sub long_output {
    my $r = shift;

    $r->content_type('text/plain');
    for (1..1_000_000) {
	print "$_ Fe fi fo fum...\n";
    }

    # The long operation above is sent to the client as HTTP 200
    # But the return statement below causes it to be logged as HTTP 400!
    return Apache2::Const::HTTP_BAD_REQUEST;
}

# in this function, headers are sent immediately, but the output is
# only sent after a short sleep
sub short_sleep {
    my $r = shift;
    
    $r->content_type('text/plain');
    $r->rflush();
    
    my $secs = 30;
    sleep($secs);
    print "Yawn... I was sleeping for $secs seconds.  Are you still there?\n";
    return Apache2::Const::OK;
}

# In this function, headers are sent immediately, but the sleep is
# very long and the connection times out before any output is received
# by the client.
sub long_sleep {
    my $r = shift;
    
    $r->content_type('text/plain');
    $r->rflush();
    
    my $secs = 330;
    sleep($secs);
    print "Yawn... I was sleeping for $secs seconds.  Are you still there?\n";
    return Apache2::Const::OK;
}

# This version does make it to the end message, because it
# periodically sends some data to the client.
sub long_sleep2 {
    my $r = shift;
    
    $r->content_type('text/plain');
    $r->rflush();
    
    my $secs = 330;
    for (1..$secs) {
	sleep(1);
	print ".";
	$r->rflush();
    }
    print "Yawn... I was sleeping for $secs seconds.  Are you still there?\n";
    return Apache2::Const::OK;
}

use CGI;
use Data::Dumper;
sub echo_params {
    my $r = shift;
    my $q = new CGI ($r);
    my $params = $q->Vars();

    $r->content_type('text/plain');
    print "params:\n", Dumper($params), "\n";
    return Apache2::Const::OK;
}

1;
