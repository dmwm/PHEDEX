#!/usr/bin/perl -w

use strict;
use Carp;
use POE;
use POE::Filter::Reference;
use POE::Component::Server::TCP;
use POE::Queue::Array;
use Getopt::Long;
use T0::StorageManager::Manager;
use T0::Logger::Sender;
use T0::Util;

my ($help,$quiet,$verbose,$debug);
my ($config,$server,$logger);

sub usage
{
  die <<EOF;

  Usage $0 <options>

  ...no detailed help yet, sorry...

EOF
}

$help = $quiet = $verbose = $debug = 0;
$config = "../Config/JulyPrototype.conf";
GetOptions(	"help"		=> \$help,
		"verbose"	=> \$verbose,
		"quiet"		=> \$quiet,
		"debug"		=> \$debug,
		"config=s"	=> \$config,
	  );
$help && usage;

sub ProfileTable
{
  my ($size,$min,$max,$step,$ref);
  my ($minp,$maxp,$table,$i,$j,$n,@s,$sum);
  $ref = shift;

  $min   = $ref->{SizeMin} or die "'SizeMin' not in $ref\n";
  $max   = $ref->{SizeMax} or die "'SizeMax' not in $ref\n";
  $step  = $ref->{SizeStep} or die "'SizeStep' not in $ref\n";
  $table = $ref->{SizeTable};

  return profile_table($min,$max,$step,$table);
}

sub ProfileFlat
{
  my ($size,$min,$max,$step,$ref);
  $ref = shift;

  $min  = $ref->{SizeMin} or die "'SizeMin' not in $ref\n";
  $max  = $ref->{SizeMax} or die "'SizeMax' not in $ref\n";
  $step = $ref->{SizeStep} or die "'SizeStep' not in $ref\n";

  return profile_flat($min,$max,$step);
}

$logger = T0::Logger::Sender->new(
		Config  => $config,
		Verbose => $verbose,
		Debug   => $debug,
		Quiet   => $quiet,
      );

$server = T0::StorageManager::Manager->new (
		Config		=> $config,
		Verbose		=> $verbose,
		Debug		=> $debug,
		Quiet		=> $quiet,
		Profile		=> \&ProfileTable,
		SelectTarget	=> \&SelectTarget,
		Logger		=> $logger,
	);

Print "I am \"",$server->Name,"\", running on ",$server->Host,':',$server->Port,". My PID is ",$$,"\n";
POE::Kernel->run();
exit;
