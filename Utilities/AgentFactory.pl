#! /usr/bin/env perl
use strict;
use warnings;

##H
##H Usage:
##H   AgentFactory.pl should be called only by Utilities/Master in order to
##H start multiple agents. Please don't use it from the command-line unless
##H you really know what you are doing.
##H

######################################################################
my (%args,$Factory,$Agents,$Config);
use Getopt::Long;
use PHEDEX::Core::Help;
use PHEDEX::Core::Config::Factory;

&GetOptions (
             "state=s"   => \$args{DROPDIR},
             "log=s"     => \$args{LOGFILE},
             "db=s"      => \$args{DBCONFIG},
             "config=s"  => \$args{CONFIG},
             "node=s"    => \$args{MYNODE},
	     "help|h"    => sub { &usage() },
	     "agent=s@"  => sub { push(@{$args{AGENTS}}, split(/,/, $_[1])) },
	     );

$Factory = PHEDEX::Core::Config::Factory->new( %args, @ARGV );
$Agents = $Factory->createAgents();
$Factory->really_daemon;

POE::Kernel->run();
print "POE kernel has ended, now I shoot myself\n";
exit 0;
