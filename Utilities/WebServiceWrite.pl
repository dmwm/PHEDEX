#!/usr/bin/perl

use strict;
use PHEDEX::Core::UserAgent;
use Getopt::Long;
use Data::Dumper;
my ($url,$response,$help,$verbose,$quiet,$h);
my ($instance,$format,$call,$args,$method,$data);
my ($proxy,$debug,$cert_file,$key_file,$ca_file,$ca_dir);

$url = 'http://localhost:7001/phedex/datasvc/';
$instance = 'prod';
$format   = 'perl';
$call     = 'nodes';
$method   = 'post';
$help = $verbose = $debug = $quiet = 0;

GetOptions
	(
	 'help'		=> \$help,
	 'verbose'	=> \$verbose,
	 'quiet'	=> \$quiet,
	 'debug'	=> \$debug,
	 'proxy=s'	=> \$proxy,
	 'cert_file=s'	=> \$cert_file,
	 'key_file=s'	=> \$key_file,
	 'ca_file=s'	=> \$ca_file,
	 'ca_dir=s'	=> \$ca_dir,
	 'url=s'	=> \$url,

	 'instance=s'	=> \$instance,
	 'format=s'	=> \$format,
	 'call=s'	=> \$call,
	 'args=s'	=> \$args,
	 'method=s'	=> \$method,

	 'data=s'	=> \$data,
	);

$url .= $format . '/' . $instance . '/' . $call;

sub usage
{
  print <<EOF;

  Usage: $0 [--proxy=s] [--cert_file=s] [--key_file=s]
	    [--instance=s] [--format=s] [--call=s] [--args]
	    [--method]
	    [--data=s]
	    [--debug] [--verbose]
	    [--url=s]

 where
 --proxy, --cert_file, and --key_file are used to define your certificate.

 --instance
 --format
 --call
 --args
 --method

 --data is the name of the XML file to upload, if any. It should contain a specification
 of data only, like the output of TMDBInject.

 --url is the URL to upload this information to, if not the default.
 --debug, --verbose, and --help are obvious

EOF
 exit 0;
}

$help && usage;

my $pua = new PHEDEX::Core::UserAgent
	(
	  DEBUG	 	=> $debug,
	  CERT_FILE	=> $cert_file,
	  KEY_FILE	=> $key_file,
	  PROXY	 	=> $proxy,
	  CA_FILE	=> $ca_file,
	  CA_DIR	=> $ca_dir,
	  URL		=> $url,
	  @ARGV,
	);

$pua->PARANOID(0);
$pua->VERBOSE($verbose);

print "Testing a simple ", uc($method)," to ",$pua->URL,"\n";
if ( $method eq 'post' )
{
  foreach ( split('&',$args) )
  {
    m%^([^=]*)=(.*)$%;
    $h->{$1} = $2;
  }
  if ( $data )
  {
    open DATA, "<$data" or die "open $data: $!\n";
    $h->{data} = join('',<DATA>);
    close DATA;
  }
}
if ( $args && $method eq 'get' ) { $url .= '?' . $args; }

if ( $h ) { $response = $pua->$method($url,$h); }
else      { $response = $pua->$method($url); }

print "Response: ",$response->content unless $quiet;
if ( $pua->response_ok($response) ) { print "Success :-)\n"; }
else                                { print "Failure :-(\n"; }

print "\nAll done...\n";
exit 0;
