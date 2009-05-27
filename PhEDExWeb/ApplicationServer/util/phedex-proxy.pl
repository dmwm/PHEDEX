#!/usr/bin/perl
use warnings;
use strict;
$|=1;
use Getopt::Long;
use POE qw(Component::Server::TCP Component::Client::HTTP Filter::HTTPD);
use HTTP::Response;
use File::Basename qw (dirname);

my ($dump_requests,$dump_responses,$listen_port,$redirect_to,$help,$verbose,$debug);
my (@accept,@reject,@map,$die_on_reject,$cache,$cache_only);
my ($delay,$cache_ro,%expires,$expires_default,$host);

@accept = qw %	^html/[^./]+.html$
		^js/[^./]+.js$
		^images/[^./]+.(gif|png|jpg)$
		^css/[^./]+.css$
		^yui/.*.js$
		favicon.ico$
	     %;
%expires =    ( '.gif'	=> 86400,
		'.jpg'	=> 86400,
		'.png'	=> 86400,
		'yui'	=>  86400,
	      );
$dump_requests = $dump_responses = $help = $verbose = $debug = 0;
$listen_port = 30001;
$redirect_to = 'http://cmswttest.cern.ch';
$die_on_reject = $cache_only = 0;
$delay = $cache_ro = $expires_default = 0;

my $dir = dirname $0;
$dir .= '/..';
chdir $dir or die "chdir $dir: $!\n";

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
 host=s			hostname for Host header. If you're tunneling to the
			webservers, you'll need to set this to avoid being
			rejected for accessing 'localhost'
 accept=s		restrict local file-serving to files matching this
			string only. Can be repeated, accepts are OR-ed.
 reject=s		reject local files that match this string. Can be
			repeated. Rejection takes precedence over acceptance.
 map=s			takes a string of the form \$key=\$value and maps the key
			to the value in all URLs, so you can serve YUI files
			without having them installed in the same directory you
			are working in, for example.
 die_on_reject		for debugging, in case your rejection criteria are wrong
 cache			directory for filesystem-based cache of requests
 cache_only		set this to serve only from whatever cache you have,
			for fully offline behaviour
 cache_ro		set the cache to be read-only, so you don't populate
			it any further.
 delay=i		delay server-response for cached entries, if you want
			to see how events unfold in the browser
 expires=i		set the default expiry time for the response header

EOF
}

GetOptions( 'help'	=> \$help,
	    'verbose+'	=> \$verbose,
	    'debug+'	=> \$debug,
	    'dump_requests'	=> \$dump_requests,
	    'dump_responses'	=> \$dump_responses,
	    'listen_port=i'	=> \$listen_port,
	    'redirect_to=s'	=> \$redirect_to,
	    'die_on_reject'	=> \$die_on_reject,
	    'accept=s'		=> \@accept,
	    'reject=s'		=> \@reject,
	    'map=s'		=> \@map,
	    'cache=s'		=> \$cache,
	    'host=s'		=> \$host,
	    'cache_only'	=> \$cache_only,
	    'cache_ro'		=> \$cache_ro,
	    'delay=i'		=> \$delay,
	    'expires=i'		=> \$expires_default,
	  );

usage() if $help;
$redirect_to =~ s%/$%%;
$host = $redirect_to unless $host;
$host =~ s%^http://%%;
$host =~ s%/$%%;
map { m%^[^=]+=(.*)$%; push @accept, $1; } @map;

if ( $cache )
{
  eval "use Cache::FileCache";
  die $@ if $@;
  $cache = new Cache::FileCache( { cache_root => $cache } );
  $cache or die "Could not create cache, have you created the $cache directory?\n";
}
die "--cache_only without --cache doesn't make much sense...\n" if $cache_only && !$cache;

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
	  sleep $delay if $delay;
	  $heap->{client}->put($data) if defined $heap->{client};
	  $kernel->yield("shutdown");
          return;
        }

        my $file = $request->uri();
        $file =~ s%^/*%%;
        $file =~ s%\.\./%%g;
	foreach ( @map )
	{
	  my ($key,$value) = split('=',$_);
	  $file =~ s%$key%$value%g;
	}
        if ( $verbose )
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
            print scalar localtime,": $file not owned by me: rejecting\n" if $debug > 1;
            goto DONE;
          }

          if ( @reject )
          {
            foreach ( @reject )
            {
              next unless $file =~ m%$_%;
              $error = "Rejecting $file, (matches $_)";
              print scalar localtime,": $file matches $_ : rejecting\n" if $debug > 1;
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
	  die "No data for $file, maybe it was rejected...?\n" if $die_on_reject && !$data;

	  my $expires = $expires_default;
          foreach ( keys %expires )
          {
            next unless $file =~ m%$_%;
            $expires = $expires{$_} if $expires{$_} > $expires;
          }
          $kernel->yield( 'send_response', $data, $error, $expires );
          return;
        }

	if ( $cache_only )
	{
#	  If I get here then the request was not served from cache and is not a local file
          $kernel->yield( 'send_response', undef, "Not found in cache");
          return;
	}

#	Transmit the request upstream to the server
	my $useragent = $request->header( 'User-Agent' );
	if ( $useragent !~ m%^PhEDEx% )
	{
	  $request->header( 'User-Agent', 'PhEDEx-Proxy-server' );
	}
	$request->header( 'Host', $host );
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
	  my ($self,$kernel,$heap,$data,$error,$expires) =
		 @_[ OBJECT, KERNEL, HEAP, ARG0, ARG1, ARG2 ];
	  my $request_fields = '';
	  my $response;
          if ( $error )
          {
            $response = HTTP::Response->new(404);
            $data = 'ERROR: ' . $error;
            print scalar localtime,': ',$data,"\n";
          }
          else { $response = HTTP::Response->new(200); }

	  $response->push_header( 'Content-type', 'text/html' );
	  $response->push_header( 'Content-length', length($data) );
	  $response->push_header( 'Max-age', $expires );
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
    if ( $cache && !$cache_ro )
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
