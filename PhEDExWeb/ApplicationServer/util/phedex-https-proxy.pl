#!/usr/bin/perl
use warnings;
use strict;
$|=1;
use Getopt::Long;
use Net::SSL; # Need this before HTTP::Daemon::SSL so that it supercedes IO::Socket::SSL!
use HTTP::Daemon::SSL;
use HTTP::Response;
use File::Basename qw (dirname);
use Term::ReadKey;
use PHEDEX::CLI::UserAgent;

my ($dump_requests,$dump_responses,$listen_port,$redirect_to,$help,$verbose,$debug);
my ($server,@accept,@reject,@map,@rewrite,$die_on_reject,$log);
my ($delay,%expires,$expires_default,$host);
my ($cert_file,$key_file,$proxy,$pk12,$nocert,$cache,$cache_ro,$cache_only);

$cache_only = $cache_ro = 0;
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
		'yui'	=>  86400,
	      );
$dump_requests = $dump_responses = $help = $verbose = $debug = 0;
$listen_port = 20001;
$redirect_to = 'https://cmswttest.cern.ch';
$die_on_reject = 0;
$delay = $expires_default = 0;

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
 rewrite=s		like the 'map' option, but works on the URI transmitted
			upstream. Essentially a URI-rewrite rule.
 die_on_reject		for debugging, in case your rejection criteria are wrong
 expires=i		set the default expiry time for the response header
 cert_file=s		location of your certificate, defaults to usercert.pem in
			~/.globus
 key_file=s		location of your user-key, defaults to userkey.pem in
			~/.globus.
 pk12=s			Use a pk12 certificate. You will be prompted for the password.
 			use this to avoid being asked for a passphrase and to
			avoid having to have a passphrase-less key-file. (i.e. it's
			more secure!). You can create a pk12 file from your certificate
			as follows:
			openssl pkcs12 -export -in usercert.pem -inkey userkey.pem -out user.p12
			(you will be prompted for an 'export password', remember it,
			you will need to enter it for this script to work!)
 logfile=s		file for logging messages from the application, for post-mortem debugging
 cache			directory for filesystem-based cache of requests
 cache_only		set this to serve only from whatever cache you have,
			for fully offline behaviour
 cache_ro		set the cache to be read-only, so you don't populate
			it any further.


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
	    'rewrite=s'		=> \@rewrite,
	    'host=s'		=> \$host,
	    'expires=i'		=> \$expires_default,
	    'cert_file=s'	=> \$cert_file,
	    'key_file=s'	=> \$key_file,
	    'proxy=s'		=> \$proxy,
	    'nocert'		=> \$nocert,
	    'pk12=s'		=> \$pk12,
	    'logfile=s'		=> \$log,
	    'cache=s'		=> \$cache,
	    'cache_only'	=> \$cache_only,
	    'cache_ro'		=> \$cache_ro,
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

my ($url,$format,$instance,$service);
if ( !( $cert_file || $key_file || $proxy || $pk12 || $nocert ||
        $ENV{HTTPS_PROXY} || $ENV{HTTPS_CERT_FILE} || $ENV{HTTPS_KEY_FILE} ) )
{
  $cert_file = $ENV{HOME} . '/.globus/usercert.pem';
  $key_file  = $ENV{HOME} . '/.globus/userkey.pem';
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

my $SSL_key_file  = '/tmp/' . $ENV{USER} . '/certs/server-key.pem';
my $SSL_cert_file = '/tmp/' . $ENV{USER} . '/certs/server-cert.pem';
( -f $SSL_key_file && -f $SSL_cert_file )
  || die "No $SSL_key_file or no $SSL_cert_file, probably you need to run make-certs.sh?\n";
$server = HTTP::Daemon::SSL->new
  ( 
    LocalPort		=> $listen_port,
    LocalAddr		=> 'localhost',
    SSL_key_file	=> $SSL_key_file,
    SSL_cert_file	=> $SSL_cert_file,
  ) || die;

print scalar localtime,": listening on port $listen_port, redirect to $redirect_to\n";
my ($c,$request,$ua);
while ( $c = $server->accept )
{
  last unless $c;
  while ( $request = $c->get_request )
  {
    last unless $request;
    my ($buf,$data,$n,$error,$h);

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
      $c->send_response($response);
      next;
    }
    if ( $cache && $debug ) # && ($file =~ m%^https*://%) )
    {
      print scalar localtime,": Look for ",$file," in cache\n";
    }
    if ( $cache && ($data = $cache->get($file)) )
    {
      print scalar localtime,": Serve ",$file," from cache...\n" if $verbose;
      $c->send_response($data);
      next;
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
      my $type = {  'css'	=> 'text/css',
                    'js'	=> 'text/javascript',
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
      send_response( $c, $data, $error, $h );
      next;
    }

    if ( $cache_only )
    {
#     If I get here then the request was not served from cache and is not a local file
      send_response($c, undef, 'Not found in cache');
      return;
    }

#   Transmit the request upstream to the server
    $request->header( 'Host', $host );
    $request->header( "Connection",       "close" );
    $request->header( "Proxy-Connection", "close" );
    $request->remove_header("Keep-Alive");
    my $target_uri = $request->uri()->path_query();
#   my $original_uri = $target_uri;
    foreach ( @rewrite )
    {
      my ($key,$value) = split('=',$_);
      if ( $target_uri !~ m%$value% ) {
        $target_uri =~ s%$key%$value%g;
      }
    }
#   print "Target URI: $target_uri\n" if $original_uri ne $target_uri;
    $request->uri($redirect_to . $target_uri);
    display_thing( $request ) if $dump_requests;
    my $uri = $request->uri;
    my $x;
    ($x = $uri) =~ s%^.*/datasvc/%%;
    my @n = split('/',$x);
    $format = $n[0];
    $instance = $n[1];
    if ( !$ua )
    {
      my %params =
        (
          DEBUG         => 0, # $debug,
          CERT_FILE     => $cert_file,
          KEY_FILE      => $key_file,
          PROXY         => $proxy,
          CA_FILE       => undef, # $ca_file,
          CA_DIR        => undef, # $ca_dir,
          URL           => $url,
          FORMAT        => $format,
          INSTANCE      => $instance,
          NOCERT        => undef, # $nocert,
          SERVICE       => $service,
        );
      $ua = PHEDEX::CLI::UserAgent->new (%params);
      $ua->CMSAgent('PhEDEx-Proxy-server-https/1.0');
      $ua->default_header('Host' => $host) if $host;
      $ua->add_handler( response_redirect => sub{
        my ($response,$ua,$h) = @_;
        my $location = $response->header('location');
        print scalar localtime, ': ',$response->code(), " => $location\n" if $location;
        return;
      });
    }
    my ($method,$response,@form);
    $method = $request->method();
    if ( $method eq 'POST' )
    {
      $_ = $request->content();
      s%=% %g;
      s%&% %g;
      @form = split(' ',$_);
      $response = $ua->post($uri,\@form);
    }
    else
    {
      $response = $ua->get($uri);
    }
    if ( $verbose ) { print scalar localtime,': ',$response->code,' ',$response->request->uri->path,"\n"; }
    $c->send_response($response);

    if ( $response->code == 200 )
    {
      if ( $cache && !$cache_ro )
      {
        my $query = $response->request()->uri()->path_query();
        $query =~ s%^/+%%;
        print scalar localtime,": Caching result for $query\n" if $verbose;
        eval
        {
          $cache->set($query,$response,86400*365*100);
        };
        if ( $@ ) { print scalar localtime," Couldn't cache result: $@\n"; }
      }
    }
  }
  $c->close;
  undef($c);
};

sub send_response {
  my ($c,$data,$error,$h) = @_;
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
  $c->send_response($response);
}

sub is_text {
  my $file = shift;
  return 1 if $file =~ m%(.txt|.htm|.html|.css|.js)$%;
  return 0;
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

exit 0;
