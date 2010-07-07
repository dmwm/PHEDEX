#!/usr/bin/perl -w

use strict;
use POE;
use Getopt::Long;
use T0::Logger::Sender;
use T0::Util;
use T0::FileWatcher;
use PHEDEX::Testbed::Lifecycle;

my ($help,$verbose,$debug,$quiet);
my ($retry,$lifecycle,%args);

sub usage
{
  die <<EOF;

  Usage $0 <options>

  ...no detailed help yet, sorry...

EOF
}

$help = $verbose = $debug = 0;
$retry = 3;
GetOptions(     "help"     => \$help,
                "verbose"  => \$verbose,
                "quiet"    => \$quiet,
                "debug"    => \$debug,
                "retry"    => \$retry,
                "state=s"  => \$args{DROPDIR},
                "log=s"    => \$args{LOGFILE},
                "db=s"     => \$args{DBCONFIG},
                "node=s"   => \$args{MYNODE},
                "config=s" => \$args{LIFECYCLE_CONFIG},
          );
$help && usage;

my %sender_args = (
			Config		=> $args{LIFECYCLE_CONFIG},
                	Verbose		=> $verbose,
                	Debug  		=> $debug,
                	Quiet   	=> $quiet,
			RetryInterval	=> $retry,
 			Name		=> 'Lifecycle::Sender',
		  );
$lifecycle = PHEDEX::Testbed::Lifecycle->new
			(
			  %args, @ARGV,
#			  SENDER_ARGS		=> \%sender_args,
			);

#my $sender = $lifecycle->{SENDER};
#Print "I am \"",$sender->Name,"\", running on ",$sender->Host,". My PID is ",$$,"\n";

POE::Kernel->run();
exit;
