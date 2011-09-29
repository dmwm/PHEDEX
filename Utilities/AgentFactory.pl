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
my (%args,$Factory,$Config);
use Getopt::Long;
use PHEDEX::Core::Help;
use PHEDEX::Core::Config::Factory;

&GetOptions (
             "state=s"		=> \$args{DROPDIR},
             "log=s"		=> \$args{LOGFILE},
             "db=s"		=> \$args{DBCONFIG},
             "config=s"		=> \$args{CONFIG},
             "node=s"		=> \$args{MYNODE},
	     "help|h"		=> sub { &usage() },
	     "agent-list=s@"	=> sub { push(@{$args{AGENT_LIST}}, split(/,/, $_[1])) },
	     "agent_list=s@"	=> sub { push(@{$args{AGENT_LIST}}, split(/,/, $_[1])) },
	     "limit=s@"		=> \$args{LIMIT},
	     "memuse"		=> sub { eval "use Devel::Size"; },
             "summary_interval=s" => \$args{_SUMMARY_INTERVAL},
             "report_plugin=s"    => \$args{_REPORT_PLUGIN},
             "notify_plugin=s"    => \$args{_NOTIFY_PLUGIN},
	     );

$Factory = PHEDEX::Core::Config::Factory->new( %args, @ARGV );
my %agent_args;
map { $agent_args{$_} = $args{$_} } qw / DBCONFIG CONFIG MYNODE /;
$Agent::Registry{AGENTS} = $Factory->createAgents( %agent_args );
$Factory->really_daemon;

POE::Kernel->run();
print "POE kernel has ended, now I shoot myself\n";
exit 0;
