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
    if (exists ${"TestModPerl::Examples\::"}{$func}) {
	return &{${"TestModPerl::Examples\::"}{$func}}($r);
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

1;
