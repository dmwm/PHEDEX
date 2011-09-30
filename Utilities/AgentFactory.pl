#! /usr/bin/env perl
use strict;
use warnings;

##H
##H Usage:
##H   AgentFactory.pl should be called only by Utilities/Master in order to
##H start multiple agents. Please don't use it from the command-line unless
##H you really know what you are doing.
##H
##H -state             agent state directory
##H -node              node name for which this agent runs
##H -db                database connection configuration parameter file
##H -log               where to redirect logging information
##H -agent_list        label (as defined in the config file) of the
##H                     agent started and monitored by the watchdog.
##H                     To run multiple agents, the option should be
##H                     repeated multiple times. 
##H -limit             limit imposed on agent resource usage, passed
##H                     in the format 'agentlabel,resource,limitvalue'
##H                     Can be repeated multiple times.
##H -summary_interval  time (in seconds) between summary report generation.
##H                     Default is 86400 (24 hours)
##H -report_plugin     format used to produce the summary report. Default is
##H                     'summary' (human readable text)
##H -notify_plugin     plugin used to notify the summary report. Default is
##H                     'log' (print report to watchdog logfile)

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
             "summary_interval=i" => \$args{_SUMMARY_INTERVAL},
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
