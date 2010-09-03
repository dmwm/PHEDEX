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
my ($server,@accept,@reject,@map,$die_on_reject,$log);
my ($delay,%expires,$expires_default,$host);
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
 die_on_reject		for debugging, in case your rejection criteria are wrong
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
	    'host=s'		=> \$host,
	    'expires=i'		=> \$expires_default,
	    'cert_file=s'	=> \$cert_file,
	    'key_file=s'	=> \$key_file,
	    'proxy=s'		=> \$proxy,
	    'nocert'		=> \$nocert,
	    'pk12=s'		=> \$pk12,
	    'logfile=s'		=> \$log,
	  );

usage() if $help;
$redirect_to =~ s%/$%%;
$host = $redirect_to unless $host;
$host =~ s%^https*://%%;
$host =~ s%/$%%;
map { m%^[^=]+=(.*)$%; push @accept, $1; } @map;

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

$server = HTTP::Daemon::SSL->new
  ( 
    LocalPort		=> $listen_port,
    LocalAddr		=> 'localhost',
    SSL_key_file	=> '/tmp/' . $ENV{USER} . '/certs/server-key.pem',
    SSL_cert_file	=> '/tmp/' . $ENV{USER} . '/certs/server-cert.pem',
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

	if ( $file =~ m%^log/([^/]+)/([^/]+)/([^/]+)$% )
	{
	  my ($level,$group,$str) = ($1,$2,$3);
	  $str =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
	  print scalar localtime, ": LOG $group/$level $str\n";
          my $response = HTTP::Response->new(200);
	  $response->header( 'Content-type', 'text/html' );
	  $response->header( 'Content-length', 0 );
          $c->send_response($response);
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
          send_response( $c, $data, $error, $h );
	  next;
        }

#	Transmit the request upstream to the server
	$request->header( 'Host', $host );
        $request->header( "Connection",       "close" );
        $request->header( "Proxy-Connection", "close" );
        $request->remove_header("Keep-Alive");
        $request->uri($redirect_to . $request->uri()->path_query());
        display_thing( $request ) if $dump_requests;
	my $uri = $request->uri;
        my $x;
        ($x = $uri) =~ s%^.*/datasvc/%%;
	my @n = split('/',$x);
	$format = $n[0];
	$instance = $n[1];
        if ( !$ua )
	{
$DB::single=1;
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
