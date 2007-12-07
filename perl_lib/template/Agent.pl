#! /usr/bin/env perl

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
