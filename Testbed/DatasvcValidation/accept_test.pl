#!/usr/bin/env perl
use warnings;
use strict;

use PHEDEX::CLI::UserAgent;
use Time::HiRes qw(gettimeofday tv_interval);
use POSIX;
use XML::Simple;
$XML::Simple::PREFERRED_PARSER = 'XML::LibXML::SAX';
use IO::File;
use Getopt::Long;
use JSON::XS;
use Data::Dumper;
$|++;

my $web_server = "cmsweb-testbed.cern.ch";
my $url_path   = "/phedex/datasvc";
my $url_instance = "/prod";
my $url_data   = "/xml/prod";
my $xml = new XML::Simple;

my $debug = 0;
my $verbose = 0;
my $test_file;
my $output;
my $help;
my ($use_cert,$cert_file,$key_file,$use_perl,$use_json,$use_cjson,$use_xml);
my ($save_file);

$use_cert = 0;
$use_perl = $use_json = $use_cjson = $use_xml = 1;
GetOptions(
    "verbose!"	    => \$verbose,
    "webserver=s"   => \$web_server,
    "path=s"	    => \$url_path,
    "debug!"	    => \$debug,
    "file=s"	    => \$test_file,
    "output|O=s"    => \$output,
    "help"	    => \$help,
    'use-cert!'     => \$use_cert,
    'cert_file=s'   => \$cert_file,
    'key_file=s'    => \$key_file,
    'xml!'	    => \$use_xml,
    'json!'	    => \$use_json,
    'cjson!'	    => \$use_cjson,
    'perl!'	    => \$use_perl,
);

if ( $use_cert )
{
  $cert_file = $ENV{HOME} . '/.globus/usercert.pem' unless $cert_file;
  $key_file  = $ENV{HOME} . '/.globus/userkey.pem'  unless $key_file;
}

sub usage()
{
    die <<EOF;

Usage: $0 [--verbose] [--debug] [--webserver <web_host>] [--path <path>] [--file <file>] [--output <dir>]

--verbose               verbose mode
--help                  show this information
--webserver <web_host>  host name with optional port number such as
                        "cmswttest.cern.ch:7001"
                        default: "cmswttest.cern.ch"
--path <path>           root path to the data service
                        default: "/phedex/datasvc"
--file <file>           file that contains test command
                        without --file, the commands are read from stdin
--ouptut <path>         save data service output to files using this as a template. Add
                        NNN.FMT, where NNN is the test number and FMT is the format of the
                        requested data. E.g --output /tmp/aa. -> files /tmp/aa.123.perl etc
                        Only failures are saved.
--debug                 turn on debugging mode

--use_cert		use a certificate for the requests. The default is not
                        to use certificates.
--cert_file <file>	your public certificate. Default is ~/.globus/usercert.pem
--key_file <file>	your private key. Default is ~/.globus/userkey.pem

--no-(xml|perl|json|cjson)	disable checking the xml/perl/json/cjson formats indivually.
                        Useful for a faster pass through the suite while developing

EOF
}

if ($help)
{
    usage();
}

my $url_prefix = "https://$web_server";

open STDERR, ">/dev/null";
our $n = 0;
sub verify
{
    # my ($url, $expect) = @_;
    my ($url_prefix, $format, $call, $expect, $key, $count) = @_;
    die "verify():  url_prefix, format, call and expect are required\n" unless $url_prefix && $expect && $format && $call;
        my $url = "${url_prefix}/${format}${url_instance}/$call";
    print "verifying '$url', expecting $expect\n" if $debug;

    my ($pua,$status,$response,$data,$content,$len,$call_time,$elapsed);
    my ($t0,$result,$tee);
    $result = "OK";
#   $tee = $output ? sprintf("tee $output/%03s.${format}|", $n) : '';
    $t0 = [gettimeofday];

    $pua = PHEDEX::CLI::UserAgent->new
	(
          DEBUG         => $debug,
          CERT_FILE     => $cert_file,
          KEY_FILE      => $key_file,
          URL           => $url_prefix,
          FORMAT        => $format,
          INSTANCE      => $url_instance,
          NOCERT        => !$use_cert,
        );
    $pua->CALL($call);
    $response = $pua->get($url);
    $status = $response->code;
    if ( $status == 200 ) {
      $content = $response->content;

      if ($format eq 'xml')
      {
        eval {
          $data = $xml->XMLin($content, ForceArray=>1);
        };
	if ( $@ ) {
	  print "Failed to eval result, illegal XML object (".$@,")\n";
          if ( $output ) {
            my $save_file = sprintf("$output%03s.${format}", $n);
            open OUT, ">$save_file" or die "open $save_file: $!\n";
            print OUT $content;
            close OUT;
          }
        }
      }
      elsif ($format eq 'perl')
      {
          my $VAR1;
	  eval {
	    { local $/ = undef; $data = eval ($content)->{'PHEDEX'} }
	  };
	  if ( $@ ) {
	    print "Failed to eval result, illegal Perl object (".$@,")\n";
            if ( $output ) {
              my $save_file = sprintf("$output%03s.${format}", $n);
              open OUT, ">$save_file" or die "open $save_file: $!\n";
              print OUT $content;
              close OUT;
            }
          }
      }
      elsif ($format eq 'json' or $format eq 'cjson')
      {
	  eval { $data = &decode_json($content)->{'phedex'}; };
	  if ( $@ ) {
            $result = "ERROR"; $n++; print "decode_json error: $@\n";
            if ( $output ) {
              my $save_file = sprintf("$output%03s.${format}", $n);
              open OUT, ">$save_file" or die "open $save_file: $!\n";
              print OUT $content;
              close OUT;
            }
          }
      }
      else #ERROR
      {
          printf "ERROR: unknown format $format\n";
          $n++;
          return;
      }
      print "got data from '$url', parsing...\n" if $debug;

      # Parse response to count elements
      $call_time = 0;
      # got to be a hash
      if (ref($data) ne "HASH")
      {
          $result = "ERROR";
      }
      else
      {
          if ($key)
          {
              my $list;
              if ($format eq "perl")
              {
                  $key = uc $key;
              }
              else
              {
                  $key = lc $key;
              }
              $list = $data->{$key};
              if (ref($list) eq "HASH")
              {
                  $len = keys %{$list};
              }
              elsif (ref($list) eq "ARRAY")
              {
                  $len = @{$list};
              }
              else
              {
		  if ($format eq 'xml')
                  {
                      $len = 0;
                  }
                  else
                  {
                      $len = undef;
                  }
              }
  
              # deal with count
              if ($count)
              {
                  my $val;
                  my $c1 = substr($count, 0, 1);
                  my $c2 = substr($count, 0, 2);
                  $val = (($c2 eq '>=') || ($c2 eq '<='))?int(substr($count, 2)):int(substr($count, 1));
                  if ($c2 eq '>=')
                  {
                      $result = ($len >= $val)?'OK':'CTERR';
                  }
                  elsif ($c2 eq '<=')
                  {
                      $result = ($len <= $val)?'OK':'CTERR';
                  }
                  elsif ($c1 eq '>')
                  {
                      $result = ($len >  $val)?'OK':'CTERR';
                  }
                  elsif ($c1 eq '<')
                  {
                      $result = ($len <  $val)?'OK':'CTERR';
                  }
                  elsif ($c1 eq '=')
                  {
                      $result = ($len ==  $val)?'OK':'CTERR';
                  }
              }
          }

          if ($format eq "perl")
          {
              $call_time = $data->{CALL_TIME};
          }
          else
          {
              $call_time = $data->{call_time};
          }
      }
    } else { # Status was not OK, use the status code as the result
      $result = $status;
    }

    $elapsed = tv_interval ( $t0, [gettimeofday]);
    # presentation of $len/count
    if (! defined $len)
    {
        $len = "  N/A  ";
    }
    else
    {
        $len = sprintf("%-7i", $len);
    }
    my $res = ($result eq $expect)?"PASS":"FAIL";
    if ( $expect eq 'ERROR' ) {
      print "# Error expected, got $result, for $url\n";
    }
    printf "%03i %4s (%5s %5s) call=%8.4f total=%8.4f count=$len %s\n", $n, $res, $expect, $result, $call_time, $elapsed, $url;
    $n++;
}

my $inf;

if ($test_file)
{
    open $inf, $test_file;
}
else
{
    print "Reading test information from STDIN\n";
    $inf = scalar *STDIN;
}

my $root_url = "${url_prefix}${url_path}${url_data}";

print "# ", &POSIX::strftime("[%Y-%m-%d %T]", gmtime), ": acceptance test of $url_prefix/$url_path\n";

while(<$inf>)
{
    chomp;
    next if /^\s*$/;
    my ($call, $key, $count) = split();
    my $c1 = substr($call, 0, 1);
    my $expect = "OK";

    if ($c1 eq "#")
    {
        # double ## is for internal use
        if (substr($call, 1, 1) ne '#')
        {
            print $_, "\n";
        }
        next;
    }

    if ($c1 eq "-")
    {
            $expect = $key || 400; # default error is 'bad request'
            $call = substr($call, 1);
    }
    #verify("$root_url/$call", $expect);
    $use_xml   && verify("${url_prefix}${url_path}",   "xml", $call, $expect, $key, $count);
    $use_perl  && verify("${url_prefix}${url_path}",  "perl", $call, $expect, $key, $count);
    $use_json  && verify("${url_prefix}${url_path}",  "json", $call, $expect, $key, $count);
    $use_cjson && verify("${url_prefix}${url_path}", "cjson", $call, $expect, $key, $count);
}
