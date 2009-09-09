#! /usr/bin/env perl
use strict;
use warnings;

##H
##H Usage:
##H   ping-watchdog.pl --config CONFIG_FILE {--text MESSAGE} {--environment ENVIRONMENT}
##H Attempt to send ping messages to the watchdog agent, to verify that your UDP
##H port configuration is correct. Optionally define the message to be sent, or
##H the environment to search from the config file to find the port-number to use
##H

######################################################################
my (%args,$config_file,$environment,$Config,$Env,$host,$port,$proto,$rname,$raddr,$msg);
use IO::Socket;
use Getopt::Long;
use PHEDEX::Core::Help;
use PHEDEX::Core::Config;

$environment = 'common';
&GetOptions (
             "config=s"		=> \$config_file,
             "environment=s"	=> \$environment,
             "text=s"		=> \$msg,
	     "help|h"		=> sub { &usage() },
	     );
defined $config_file || usage();
$Config = PHEDEX::Core::Config->new();
$Config->readConfig($config_file);
$Env = $Config->ENVIRONMENTS->{$environment};
die "Cannot find environment \"$environment\" in $config_file, aborting\n" unless $Env;
$port = $Env->getExpandedParameter('PHEDEX_NOTIFICATION_PORT');
$host = $Env->getExpandedParameter('PHEDEX_NOTIFICATION_HOST') || 'localhost';

die "PHEDEX_NOTIFICATION_PORT not defined in the $environment environment, aborting\n" unless $port;

$msg ||= "this is $0 pinging the watchdog on port=$port, host=$host";
$proto=getprotobyname('udp');
socket(SOCKET, PF_INET, SOCK_DGRAM, $proto) or die "Cannot create socket: $!";
$rname=gethostbyname($host) or die "No such host $host: $!";
$raddr=pack_sockaddr_in($port,$rname);
print "Sending \"$msg\" to port=$port on host=$host\n";
$msg .= "\n";
send(SOCKET,$msg,0,$raddr);

exit 0;
