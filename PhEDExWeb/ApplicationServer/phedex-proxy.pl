#!/usr/bin/perl
use warnings;
use strict;
$|=1;
use Getopt::Long;
use POE qw(Component::Server::TCP Component::Client::HTTP Filter::HTTPD);
use HTTP::Response;

my ($dump_requests,$dump_responses,$listen_port,$redirect_to,$help,$verbose,$debug);
my (@accept,@reject,$die_on_reject,$cache);

@accept = qw %	phedex[^./]*.html$
		^js/[^./]+.js$
		^images/[^./]+.(gif|png|jpg)$
		^css/[^./]+.css$
		^yui/.*.js$
		favicon.ico$
	     %;
$dump_requests = $dump_responses = $help = $verbose = $debug = 0;
$listen_port = 30001;
$redirect_to = 'http://cmswttest.cern.ch';
$redirect_to = 'http://localhost:30002';
$die_on_reject = 1;

sub usage()
{
  die <<EOF;

 Usage: $0 <options>
 where options are:

 help, verbose, debug	Obvious...
 dump_requests		Dump all request headers
 dump_responses		Dump all response headers
 listen_port=i		Port to accept requests on (default: $listen_port)
 redirect_to=s		url to redirect to for non-local files. I.e. base
			address of the data-service behind the proxy
			(default is $redirect_to)
 accept=s		restrict local file-serving to files matching this
			string only. Can be repeated, accepts are OR-ed.
 reject=s		reject local files that match this string. Can be
			repeated. Rejection takes precedence over acceptance.
 die_on_reject		(1|0) default is $die_on_reject
 cache			directory for filesystem-based cache of requests

EOF
}

GetOptions( 'help'	=> \$help,
	    'verbose+'	=> \$verbose,
	    'debug+'	=> \$debug,
	    'dump_requests'	=> \$dump_requests,
	    'dump_responses'	=> \$dump_responses,
	    'listen_port=i'	=> \$listen_port,
	    'redirect_to=s'	=> \$redirect_to,
	    'die_on_reject=i'	=> \$die_on_reject,
	    'accept=s'		=> \@accept,
	    'reject=s'		=> \@reject,
	    'cache=s'		=> \$cache,
	  );

usage() if $help;
$redirect_to =~ s%/$%%;

if ( $cache )
{
  eval "use Cache::FileCache";
  die $@ if $@;
  $cache = new Cache::FileCache( { cache_root => $cache } );
  $cache or die "Could not create cache\n";
}

POE::Component::Client::HTTP->spawn( Alias => 'ua' );

POE::Component::Server::TCP->new
  ( Alias => "web_server",
    Port         => $listen_port,
    ClientFilter => 'POE::Filter::HTTPD',

    ClientInput => sub {
        my ( $kernel, $heap, $request ) = @_[ KERNEL, HEAP, ARG0 ];
	my ($buf,$data,$n,$error);

        if ( $request->isa("HTTP::Response") ) {
            $heap->{client}->put($request);
            $kernel->yield("shutdown");
            return;
        }

        if ( $debug && ($request->uri() =~ m%^http://%) )
        {
          print scalar localtime,": Look for ",$request->uri()," in cache\n";
        }
        if ( $cache && ($data = $cache->get($request->uri())) )
        {
	  print scalar localtime,": Serve ",$request->uri()," from cache...\n" if $verbose;
	  $heap->{client}->put($data) if defined $heap->{client};
	  $kernel->yield("shutdown");
          return;
        }

        my $file = $request->uri();
        $file =~ s%^/*%%;
        $file =~ s%\.\./%%g;
        if ( $debug > 1 )
        {
          print scalar localtime,': ', $request->method(),' ', $request->uri()->as_string();
          print ' (exists locally)' if -f $file;
          print "\n";
        }
        if ( -f $file )
        {
          if ( $< != (stat($file))[4] )
          {
            $error = "Refuse to open $file, I do not own it";
            goto DONE;
          }

          if ( @reject )
          {
            foreach ( @reject )
            {
              next unless $file =~ m%$_%;
              $error = "Rejecting $file, (matches $_)";
              goto DONE;
            }
          }
          if ( @accept )
          {
            my $accept = 0;
            foreach ( @accept )
            {
              next unless $file =~ m%$_%;
              print scalar localtime,": $file matches $_ : accepting\n" if $debug > 1;
              $accept++; last;
            }
            if ( !$accept )
            {
              $error = "Rejecting $file, (does not match any of \"" . join(", ",@accept) . "\")";
              goto DONE;
            }
          }
          open DATA, "<$file" or do {
                                      $error = "failed to open $file: $!";
                                      goto DONE;
                                    };
	  binmode DATA if ! is_text($file);# !~ m%(.txt|.htm|.html|.css|.js)$%;
	  while ( read(DATA,$buf,4096) ) { $data .= $buf; } 
          close DATA;
DONE:
	  die "No data for $file\n" if $die_on_reject && !$data;
          $kernel->yield( 'send_response', $data, $error );
          return;
        }

        $request->header( "Connection",       "close" );
        $request->header( "Proxy-Connection", "close" );
        $request->remove_header("Keep-Alive");
        $request->uri($redirect_to . $request->uri()->path_query());
        display_thing( $request ) if $dump_requests;
        $kernel->post( "ua" => "request", "got_response", $request );
      },

    InlineStates => {
	'send_response' => sub
	{
	  my ($self,$kernel,$heap,$data,$error) = @_[ OBJECT, KERNEL, HEAP, ARG0, ARG1 ];
	  my $request_fields = '';
	  my $response;
          if ( $error )
          {
            $response = HTTP::Response->new(404);
            $data = 'ERROR: ' . $error;
            print scalar localtime,': ',$error,"\n";
          }
          else { $response = HTTP::Response->new(200); }

	  $response->push_header( 'Content-type', 'text/html' );
	  $response->push_header( 'Content-length', length($data) );
	  $response->content($data);
	  $heap->{client}->put($response);
	  $kernel->yield("shutdown");
	},
        got_response => \&handle_http_response,
      },
  );

sub is_text
{
  my $file = shift;
  return 1 if $file =~ m%(.txt|.htm|.html|.css|.js)$%;
  return 0;
}

sub handle_http_response {
    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
    my $http_response = $_[ARG1]->[0];
    my $response_type = $http_response->content_type();
    if ( $response_type =~ /^text/i ) {
        display_thing( $http_response ) if $dump_responses;
    }
    else {
        print "Response wasn't text.\n" if $dump_responses;
    }
    if ( $cache )
    {
      my $query = $http_response->request()->uri()->path_query();
      $query =~ s%^/\/+%/%;
      print scalar localtime,": Caching result for $query\n" if $verbose;
      $cache->set($query,$http_response,86400*365*100);
    }
    $heap->{client}->put($http_response) if defined $heap->{client};
    $kernel->yield("shutdown");
}

sub display_thing {
    my $thing = shift;
    my $h = $thing->headers();
    my $uri;
    if ( $thing->can('uri') ) { $uri = $thing->uri(); }
    else { $uri = $thing->request()->uri(); }

    print '-' x 78, "\n";
    print "URI => $uri\n";
    foreach ( sort keys %{$h} ) { print "$_ => $h->{$_}\n"; }
    print '-' x 78, "\n";
}

print scalar localtime,": listening on port $listen_port, redirect to $redirect_to\n";
$poe_kernel->run();
exit 0;
