#!/usr/bin/perl -w

use strict;
use POE;
use Getopt::Long;
use T0::StorageManager::Worker;
use T0::Logger::Sender;
use T0::Util;

my ($help,$verbose,$debug,$quiet);
my ($config,$client,$logger);

sub usage
{
  die <<EOF;

  Usage $0 <options>

  ...no detailed help yet, sorry...

EOF
}

$help = $verbose = $debug = 0;
$config = "../Config/JulyPrototype.conf";
GetOptions(     "help"          => \$help,
                "verbose"       => \$verbose,
                "quiet"         => \$quiet,
                "debug"         => \$debug,
                "config=s"      => \$config,
          );
$help && usage;

$logger = T0::Logger::Sender->new(
                Config  => $config,
                Verbose => $verbose,
                Debug   => $debug,
                Quiet   => $quiet,
      );

$client = T0::StorageManager::Worker->new(
		Config	=> $config,
                Verbose => $verbose,
                Debug   => $debug,
                Quiet   => $quiet,
		Logger	=> $logger,
	);

Print "I am \"",$client->Name,"\", running on ",$client->Host,". My PID is ",$$,"\n";
POE::Kernel->run();
exit;
