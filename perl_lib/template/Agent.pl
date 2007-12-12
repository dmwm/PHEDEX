#! /usr/bin/env perl

#
# This is a template agent. All the complexity of the agent behaviour should
# be implemented in the agent's modules, so this main program should be very
# simple. Command-line arguments are processed (minimally), the agent is
# started, and the "process" method is called. That's it.
#
# The arguments are not validated in this main program. The agent is expected
# to validate itself in the "isInvalid" method. See template/Agent.pm for
# details.
#
# Note also that any unused arguments are passed to the constructor, as well
# as the processed/recognised arguments. This allows you to pass arbitrary
# arguments on the command line, overriding anything that you hadn't foreseen
# the need to provide a hook for. The processed arguments provide standard
# handling, especially useful for historically-named arguments which are
# represented by hash-keys with different names.
#
# To prevent passing arguments to the GetOptions routine, use a '--' on the
# command-line. Strings following that will be ignored by GetOptions, and will
# remain in @ARGS. So you can pass the same argument in more than one way:
#
# ./Agent.pl --MYNODE myhost --log /path/to/log
#
# or
#
# ./Agent.pl -- NODE myhost LOGFILE /path/to/log
#
# This is particulrly useful for passing things like WAITTIME, to reduce the
# agent sleep-time during debugging cycles.
#

##H template agent
##H
##H Usage:
##H   Agent.pl args, where args are up to you!
##H
##H Certain arguments are obligatory, you'll discover that if you run
##H the agent and don't define them. They aren't listed here because that
##H would couple this help file to the internals of PHEDEX::Core::Agent,
##H and I don't want to do that. Specify them on the command-line as 
##H follows:
##H
##H Agent.pl -- OPTION1 value1 OPTION2 value2
##H ...with no leading dashes before the options.
##H
##H E.g:
##H  Agent.pl -- MYNODE asdf DBCONFIG fds DROPDIR a/ NODAEMON 1 WAITTIME 2
##H

######################################################################
my %args;
use Getopt::Long;
use PHEDEX::Core::Help;
use template::Agent;

&GetOptions ("state=s"     => \$args{DROPDIR},
	     "log=s"       => \$args{LOGFILE},
             "db=s"        => \$args{DBCONFIG},
             "node=s"      => \$args{MYNODE},
	     "help|h"      => sub { &usage() });

(new template::Agent (%args,@ARGV))->process();
