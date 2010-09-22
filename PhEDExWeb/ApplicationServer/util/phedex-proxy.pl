#!/usr/bin/perl
use warnings;
use strict;
$|=1;
use Getopt::Long;
use POE qw(Component::Server::TCP);
use HTTP::Response;
use File::Basename qw (dirname);
use Term::ReadKey;
use PHEDEX::CLI::UserAgent;

my ($dump_requests,$dump_responses,$listen_port,$redirect_to,$help,$verbose,$debug,$ua);
my (@accept,@reject,@map,@uriMap,$die_on_reject,$cache,$cache_only,$log,$autotruncate,$newUrl);
my ($delay,$cache_ro,%expires,$expires_default,$host);
my ($cert_file,$key_file,$proxy,$pk12,$nocert);

@accept = qw %	^html/[^./]+.html$
		^examples/[^./]+.html$
		^js/[^./]+.js$
		^images/[^./]+.(gif|png|jpg)$
		^css/[^./]+.css$
		^yui/.*.(js|css|gif|png|jpg)$
		favicon.ico$
	     %;
%expires =    ( '.gif'	=> 86400,
		'.jpg'	=> 86400,
		'.png'	=> 86400,
		'yui'	=> 86400,
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
 urimap=s		like the 'map' option, but applies after other matching,
			and can map full urls. So can be used to redirect a
			request to a completely different server than the default.
 die_on_reject		for debugging, in case your rejection criteria are wrong
 cache			directory for filesystem-based cache of requests
 cache_only		set this to serve only from whatever cache you have,
			for fully offline behaviour
 cache_ro		set the cache to be read-only, so you don't populate
			it any further.
 delay=i		delay server-response for cached entries, if you want
			to see how events unfold in the browser
 expires=i		set the default expiry time for the response header
 cert_file=s		location of your certificate, defaults to usercert.pem in
			~/.globus
 key_file=s		location of your user-key, defaults to userkey.pem.nok in
			~/.globus. N.B. If you don't want to have to type in your
			passphrase with every request, create a key-file with the
			passphrase stripped from it. Do this only on secure
			machines, not ones that just anybody can access!
			You can strip the passphrase from a key-file as follows:
			openssl rsa -in userkey.pem -out userkey.pem.nok
 pk12=s			Use a pk12 certificate. You will be prompted for the password.
 			use this to avoid being asked for a passphrase and to
			avoid having to have a passphrase-less key-file. (i.e. it's
			more secure!). You can create a pk12 file from your certificate
			as follows:
			openssl pkcs12 -export -in usercert.pem -inkey userkey.pem -out user.p12
			(you will be prompted for an 'export password', remember it,
			you will need to enter it for this script to work!)
 logfile=s		file for logging messages from the application, for post-mortem debugging

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
	    'urimap=s'		=> \@uriMap,
	    'cache=s'		=> \$cache,
	    'host=s'		=> \$host,
	    'cache_only'	=> \$cache_only,
	    'cache_ro'		=> \$cache_ro,
	    'delay=i'		=> \$delay,
	    'expires=i'		=> \$expires_default,
	    'cert_file=s'	=> \$cert_file,
	    'key_file=s'	=> \$key_file,
	    'proxy=s'		=> \$proxy,
	    'nocert'		=> \$nocert,
	    'pk12=s'		=> \$pk12,
	    'logfile=s'		=> \$log,
	    'autotruncate'	=> \$autotruncate,
	  );

usage() if $help;
$redirect_to =~ s%/$%%;
$host = $redirect_to unless $host;
$host =~ s%^https*://%%;
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

#-----------------------------------------------------------
#POE::Component::Client::HTTP->spawn( Alias => 'ua' );
#-----------------------------------------------------------
my ($url,$format,$instance,$service);
if ( !( $cert_file || $key_file || $proxy || $pk12 || $nocert ||
        $ENV{HTTPS_PROXY} || $ENV{HTTPS_CERT_FILE} || $ENV{HTTPS_KEY_FILE} ) )
{
  $cert_file = $ENV{HOME} . '/.globus/usercert.pem';
  $key_file  = $ENV{HOME} . '/.globus/userkey.pem.nok';
}
if ( $pk12 )
{
  $ENV{HTTPS_PKCS12_FILE} = $pk12;
  print "Enter the password for $pk12: ";
  ReadMode 'noecho';
  my $password = ReadLine 0;
  chomp $password;
  ReadMode 'normal';
  print "Got it, thanks...\n";
  $ENV{HTTPS_PKCS12_PASSWORD} = $password;
}

sub writeLog
{
  my $pid;
  return if $pid = open(STDOUT, "|-");
  die "cannot fork: $!" unless defined $pid;
  while (<STDIN>) {
    print;
    open LOG, ">>$log" or die "Cannot open $log for append: $!\n";
    print LOG;
    close LOG;
  }
  exit;
}
writeLog() if $log;

#-----------------------------------------------------------

POE::Component::Server::TCP->new
  ( Alias => "web_server",
    Port         => $listen_port,
    ClientFilter => 'POE::Filter::HTTPD',

    ClientInput => sub {
        my ( $kernel, $heap, $request ) = @_[ KERNEL, HEAP, ARG0 ];
	my ($buf,$data,$n,$error,$h);
        if ( $request->isa("HTTP::Response") ) {
            $heap->{client}->put($request);
            $kernel->yield("shutdown");
            return;
        }
        if ( $debug && ($request->uri() =~ m%^https*://%) )
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

	if ( $file =~ m%^phedex(/dev.)?/datasvc/log/([^/]+)/([^/]+)/(.+)$% )
	{
	  my ($level,$group,$str) = ($2,$3,$4);
	  $str =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
	  print scalar localtime, ": LOG $group/$level $str\n";
          my $response = HTTP::Response->new(200);
	  $response->header( 'Content-type', 'text/html' );
	  $response->header( 'Content-length', 0 );
	  $heap->{client}->put($response);
	  $kernel->yield("shutdown");
	  return;
	}

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
          if ( $file =~ m%.html$% && $log && $autotruncate )
          {
            open LOG, ">$log" or die "Cannot open $log to truncate it: $!\n";
            close LOG;
            print "Truncated logfile upon request for $file\n";
          }

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
	  $h->{'Content-type'} = 'text/html';
	  $file  =~ m%\.([^\.]+)$%;
	  my $ext = $1;
	  my $type = {	'css'	=> 'text/css',
			'js'    => 'text/javascript',
			'gif'	=> 'image/gif',
			'png'	=> 'image/png',
			'jpeg'	=> 'image/jpg',
			'jpg'	=> 'image/jpg',
			'ico'	=> 'image/ico',
		     }->{$ext};
	  $h->{'Content-type'} = $type if $type;
	  binmode DATA if ! is_text($file);
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
	  $h->{'Max-age'} = $expires;
          $kernel->yield( 'send_response', $data, $error, $h );
          return;
        }

	if ( $cache_only )
	{
#	  If I get here then the request was not served from cache and is not a local file
          $kernel->yield( 'send_response', undef, "Not found in cache");
          return;
	}

#	Transmit the request upstream to the server
	$request->header( 'Host', $host );
        $request->header( "Connection",       "close" );
        $request->header( "Proxy-Connection", "close" );
        $request->remove_header("Keep-Alive");
        $newUrl = $request->uri()->path_query();
	foreach ( @uriMap )
	{
	  my ($key,$value) = split('=',$_);
	  $newUrl =~ s%$key%$value%g;
	}
        if ( $newUrl !~ m%^http://% ) { $newUrl = $redirect_to . $newUrl; }
        $request->uri($newUrl);
        display_thing( $request ) if $dump_requests;
	my $uri = $request->uri;
	my @n = split('/',$uri);
	$format = $n[5];
	$instance = $n[6];
	if ( !$ua )
	{
	  $ua = PHEDEX::CLI::UserAgent->new
          (
            DEBUG         => 0, # $debug,
            CERT_FILE     => $cert_file,
            KEY_FILE      => $key_file,
            PROXY         => $proxy,
            CA_FILE       => undef, # $ca_file,
            CA_DIR        => undef, # $ca_dir,
            URL           => $url,
            FORMAT        => $n[5],
            INSTANCE      => $n[6],
            NOCERT        => undef, # $nocert,
            SERVICE       => $service,
          );
	  $ua->default_header('Host' => $host) if $host;
	  $ua->CMSAgent('PhEDEx-Proxy-server/1.0');
	}
	my ($method,$response,@form);
	$method = lc $request->method();
        @form = $uri->query_form();
	$response = $ua->$method($uri,\@form);
	if ( $verbose ) { print scalar localtime,': ',$response->code,' ',$response->request->uri->path,"\n"; }
        $heap->{client}->put($response);
	handle_http_response($response);
        $kernel->yield("shutdown");
      },

    InlineStates => {
	'send_response' => sub
	{
	  my ($self,$kernel,$heap,$data,$error,$h) =
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

	  $response->header( 'Content-type', 'text/html' );
	  $response->header( 'Content-length', length($data) );
	  $h && $response->header( %{$h} ); # Override-with/append our headers
	  $response->content($data);
	  $heap->{client}->put($response);
	  $kernel->yield("shutdown");
	},
      },
  );

sub is_text
{
  my $file = shift;
  return 1 if $file =~ m%(.txt|.htm|.html|.css|.js)$%;
  return 0;
}

sub handle_http_response {
    my $http_response = shift;
    my $response_type = $http_response->content_type();
    if ( $response_type =~ /^text/i ) {
        display_thing( $http_response ) if $dump_responses;
    }
    else {
        print "Response wasn't text.\n" if $dump_responses;
    }
    if ( $http_response->code != 200 ) { return; }
    if ( $cache && !$cache_ro )
    {
      my $query = $http_response->request()->uri()->path_query();
      $query =~ s%^/\/+%/%;
      print scalar localtime,": Caching result for $query\n" if $verbose;
      eval
      {
        $cache->set($query,$http_response,86400*365*100);
      };
      if ( $@ ) { print scalar localtime," Couldn't cache result: $@\n"; }
    }
}

sub display_thing {
    my $thing = shift;
    my $h = $thing->headers();
    my $uri;
    if ( $thing->can('uri') ) { $uri = $thing->uri(); }
    else { $uri = $thing->request()->uri(); }

    print '-' x 78, "\n";
    print "URI => $uri\n";
    if ( $thing->can('method') ) { print "METHOD => ",$thing->method(),"\n"; }
    foreach ( sort keys %{$h} ) { print "$_ => $h->{$_}\n"; }
    print '-' x 78, "\n";
}

print scalar localtime,": listening on port $listen_port, redirect to $redirect_to\n";
$poe_kernel->run();
exit 0;
