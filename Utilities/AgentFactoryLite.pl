#! /usr/bin/env perl
use strict;
use warnings;

##H
##H Usage:
##H   AgentFactoryLite.pl should be called only by Utilities/Master in order to
##H start multiple agents. Please don't use it from the command-line unless
##H you really know what you are doing.
##H

######################################################################
my (%args,$Factory,$Config);
use Getopt::Long;
use PHEDEX::Core::Help;
use PHEDEX::Core::Config::FactoryLite;

&GetOptions (
             "node=s"		=> \$args{MYNODE},
             "state=s"          => \$args{DROPDIR},
             "log=s"		=> \$args{LOGFILE},
             "config=s"		=> \$args{CONFIG},
	     "help|h"		=> sub { &usage() },
	     "agent-list=s@"	=> sub { push(@{$args{AGENT_LIST}}, split(/,/, $_[1])) },
	     "agent_list=s@"	=> sub { push(@{$args{AGENT_LIST}}, split(/,/, $_[1])) },
	     );

$Factory = PHEDEX::Core::Config::FactoryLite->new( %args, @ARGV );
my %agent_args;
map { $agent_args{$_} = $args{$_} } qw / CONFIG /;
$Agent::Registry{AGENTS} = $Factory->createAgents( %agent_args );
$Factory->really_daemon;

POE::Kernel->run();
print "POE kernel has ended, now I shoot myself\n";
exit 0;
