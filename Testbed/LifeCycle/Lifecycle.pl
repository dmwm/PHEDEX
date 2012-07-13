#!/usr/bin/perl -w

use strict;
#sub POE::Kernel::TRACE_DEFAULT  () { 1 }
#sub POE::Kernel::TRACE_EVENTS   () { 1 }
#sub POE::Kernel::TRACE_SESSIONS () { 1 }
#sub POE::Kernel::TRACE_DESTROY () { 1 }

use POE;
use Getopt::Long;
#use T0::Logger::Sender;
use T0::Util;
use T0::FileWatcher;
use PHEDEX::Testbed::Lifecycle::Agent;

my ($help,$verbose,$debug,$quiet);
my ($retry,$lifecycle,%args);

$|=1;
sub usage
{
  die <<EOF;

 Usage $0 <options>

 where options include:
 --config <name of config file> (obligatory)
 --log    <name of log file> Causes agent to run as a daemon and write it's output to the
          named logfile
 --state  <name of directory> write a PID file to this directory if running as a daemon.
          defaults to the same name as the logfile with s/log$/pid$/.
 --help   I guess you know what this one does by now :-)

 See https://twiki.cern.ch/twiki/bin/view/CMS/PhedexProjLifeCycleTestbed for detailed
documentation on the Lifecycle agent.

EOF
}

$help = $verbose = $debug = 0;
$retry = 3;
GetOptions(     "help"      => \$help,
                "verbose"   => \$verbose,
                "quiet"     => \$quiet,
                "debug"     => \$debug,
#                "retry"    => \$retry,
                "state=s"   => \$args{DROPDIR},
                "logfile=s" => \$args{LOGFILE},
                "config=s"  => \$args{LIFECYCLE_CONFIG},
          );
$help && usage;
if ( !defined $args{LIFECYCLE_CONFIG} )
{
  die "--config=<config-file> not given\n";
}
if ( ! -f $args{LIFECYCLE_CONFIG} )
{
  die "config-file $args{LIFECYCLE_CONFIG} not found\n";
}

my %sender_args = (
			Config		=> $args{LIFECYCLE_CONFIG},
                	Verbose		=> $verbose,
                	Debug  		=> $debug,
                	Quiet   	=> $quiet,
			RetryInterval	=> $retry,
 			Name		=> 'Lifecycle::Sender',
		  );
$lifecycle = PHEDEX::Testbed::Lifecycle::Agent->new
			(
			  %args, @ARGV,
#			  SENDER_ARGS		=> \%sender_args,
			);

#my $sender = $lifecycle->{SENDER};
#Print "I am \"",$sender->Name,"\", running on ",$sender->Host,". My PID is ",$$,"\n";

POE::Kernel->run();
exit;
