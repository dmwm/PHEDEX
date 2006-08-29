#!/usr/bin/perl -w

use strict;
use T0::Iterator::Rfdir;
use POE;
use T0::Util;
use Getopt::Long;

my ($help,$verbose,$debug,$quiet);
my ($config);
my ($file,@files,$size,@sizes,$dir,$interval);
my ($i,$iterator);

sub usage
{
  die <<EOF;

  Usage $0 <options>

  ...no detailed help yet, sorry...

EOF
}

$i = 0;
$help = $verbose = $debug = 0;
$interval  = 1.0;
$config = "../Config/ExportFeeder.conf";
$dir    = "/castor/cern.ch/cms/T0Prototype/t0export";
GetOptions(     "help"          => \$help,
                "verbose"       => \$verbose,
                "quiet"         => \$quiet,
                "debug"         => \$debug,
                "config=s"      => \$config,
		"dir=s"		=> \$dir,
          );
$help && usage;

sub MakeDrop
{
  my ( $kernel ) = $_[ KERNEL ];
  ($file,$size) = $iterator->Next;
  defined($file) or exit;

  T0::Util::ReadConfig( 0, 0 ,$config);

  my %text;
  $text{ExportReady} = $file;
  $text{Size}        = $size;
  $text{Checksum}    = 0;

  if ( defined($Export::Feeder{DropScript}) )
  {
    my $dataset = bin_table($Export::Feeder{T1Rates});
    $dataset = "T0-Test-" . (split('','ABCDEFGHIJKLMNOPQRSTUVWXYZ'))[$dataset];
    my $c = $Export::Feeder{DropScript} . " $file $size 0 $dataset";
    open DROP, "$c |" or die "open: $c: $!\n";
    while ( <DROP> ) { }
    close DROP or die "close: $c: $!\n";
  }

  my $rate;
  if ( defined($rate = $Export::Feeder{DataRate}) )
  {
    $interval = $size / (1024*1024) / $rate;
    $interval = int(1000*$interval)/1000;
    T0::Util::Print ("Set interval=$interval for ",$rate," MB/sec\n");
  }

  if ( $interval ) { $kernel->delay_set( 'MakeDrop', $interval ); }
  else { $kernel->yield( 'MakeDrop' ); }
  return 1;
}

sub Start
{
  my ( $heap, $kernel, $session ) = @_[ HEAP, KERNEL, SESSION ];

  $kernel->state( 'MakeDrop', \&MakeDrop );
  $kernel->yield( 'MakeDrop' );
  return 0;
}

$iterator = T0::Iterator::Rfdir->new( Directory => $dir);

T0::Util::ReadConfig( 0 , 0 ,$config);
POE::Session->create(
    inline_states => {
      _start	=> \&Start,
      MakeDrop	=> \&MakeDrop,
    },
);

POE::Kernel->run();
exit;
