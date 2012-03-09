#!/usr/bin/perl -w
use strict;
#sub POE::Kernel::TRACE_DEFAULT  () { 1 }
#sub POE::Kernel::TRACE_EVENTS   () { 1 }
#sub POE::Kernel::TRACE_SESSIONS () { 1 }
#sub POE::Kernel::TRACE_DESTROY () { 1 }
use POE;
use Getopt::Long;
use T0::Util;
use T0::FileWatcher;
use PHEDEX::Testbed::Lifecycle::Lite;

my ($help,$verbose,$debug,$quiet);
my ($retry,$lifecycle,%args);

$|=1;
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
if ( !defined $args{LIFECYCLE_CONFIG} )
{
  die "--config=<config-file> not given\n";
}
if ( ! -f $args{LIFECYCLE_CONFIG} )
{
  die "config-file $args{LIFECYCLE_CONFIG} not found\n";
}

$lifecycle = PHEDEX::Testbed::Lifecycle::Lite->new(%args,@ARGV);

POE::Kernel->run();
exit;
