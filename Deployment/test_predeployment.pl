#!/usr/bin/env perl

BEGIN
{
    use strict; use warnings; use Getopt::Long;
}

#--------------------------------------------------------------------
# things this script should check:
# 1. availability of transfer tools
# 2. availability of Perl DBI modules and quick check they do work
# 3. check grid certificate
# 4. check for POOL FC tools and make sure a MySQL DB can be accessed
#--------------------------------------------------------------------


# get arguments
my %args = (DBTYPE => 'Oracle');
my $OK = 1;

&GetOptions ("help"                     => \$args{HELP},
	     "dbtype=s"                 => \$args{DBTYPE},
	     "dbname=s"                 => \$args{DBNAME},
	     "dbuser=s"                 => \$args{DBUSER},
	     "dbpass=s"                 => \$args{DBPASS},
	     "poolcat=s"                => \$args{POOLCAT});

if ($args{HELP} || !$args{DBNAME} || !$args{DBUSER} || !$args{DBPASS}
    || !$args{POOLCAT} )
{
    print STDERR "Usage:\n";
    print STDERR "-help:    shows this help text\n";
    print STDERR "-dbname:  name of DB to connect to\n";
    print STDERR "-dbuser:  user for DB connection\n";
    print STDERR "-dbpass:  password for DB connection\n";
    print STDERR "-poolcat: MySQL POOL contact string\n";
    print STDERR "-dbtype:  type of DB (defaults to ORACLE)\n";
    exit 1;
}

# execute one test after the other
$OK *= &testTools();
$OK *= &testOracle($args{DBTYPE},$args{DBNAME},$args{DBUSER},$args{DBPASS});
$OK *= &testGridCert();
$OK *= &testPOOLSetup($args{POOLCAT});


# judge whether there is a chance to run successfully
print "\n";
if ($OK)
{
    print "Your setup seems to provide all requirements\n";
    print "Please check that all transfer methods you intended to use\n";
    print "are marked as working in the above listing\n";
}
else
{
    print "Your setup is missing some crucial parts. Please check !\n";
    exit 1;
}

exit 0;



#---------------------
# Test routines
#---------------------

sub testTools
{
    # try to identify and execute available transfer tools
    my %ttools = ('globus-url-copy'   =>'not available',
		  'srmcp'             =>'not available',
		  'rfcp'              =>'not available',
		  'dccp'              =>'not available');

    print "checking availability for ".scalar(keys(%ttools))." tools:\n";
    print "---------------------------------------------------------\n";
    foreach my $tool (keys %ttools)
    {
	# check if we find the binaries for that tool
	my $absent = system("which $tool >& /dev/null");
	$ttools{$tool} = 'binary exists in path, but execution failed' if ! $absent;
	
	# check if the tools are executable
	my $executable  = `sh -c '$tool -h 2>&1 |grep -i usage'` if !$absent;
	$ttools{$tool} = 'transfer tool available and executable' if $executable;
	
	#finally tell user the status of that tool
	print "$tool: $ttools{$tool}\n";
    }
    print "---------------------------------------------------------\n";
    return 0 if (!grep($_ !~ 'not available',(keys(%ttools)))); # report failure
    return 1; # report success
}

sub testOracle
{
    my ($DBType, $DBName, $DBUser, $DBPass) = @_;
    
    # ORACLE_HOME must be set properly
    my $ORACLE = $ENV{ORACLE_HOME};
    do {print "ORACLE_HOME is not set... Please set it correctly !!\n";
	print "---------------------------------------------------------\n";
	return 0} if !$ORACLE;

    # TNSAdmin must be set properly
    my $TNSADMIN = $ENV{TNS_ADMIN};
    do {print "TNS_ADMIN is not set... Please set it correctly !!\n";
	print "---------------------------------------------------------\n";
	return 0} if !$TNSADMIN;
    
    # try to use the DBD modules to connect and disconnect from TMDB
    eval
    {
	BEGIN{
	    # make sure we find the DBI module....
	    # PERL5LIB must be set properly
	    my $PERL5LIB = $ENV{PERL5LIB};
	    do {print "---------------------------------------------------------\n";
		print "PERL5LIB is not set ! It should include the DBI modules !\n";
		print "---------------------------------------------------------\n";
		exit 5} if !$PERL5LIB;
	    do {print "--------------------------------\n";
		print "DBI module wasn't found !!\n";
		print "--------------------------------\n";
		exit 10} if (! -e "$PERL5LIB/DBI.pm");
	}

	# now get the DBI module
	use DBI;
	#try connecting to the DB
	my $DBH = DBI->connect("DBI:$DBType:$DBName",
			       $DBUser, $DBPass,
			       { RaiseError => 1, AutoCommit => 0 })
	    or die "Couldn't connect to DB $DBNAME !!\n";
	# disconnect
	$DBH->disconnect() if $DBH;
    };
    do {print "Didn't succeed in using the DBD modules....\n";
	print "Error was: $@\n";
	print "---------------------------------------------------------\n";
	return 0} if $@;
    
    print "DBD perl modules found and successfully accessed TMDB\n";
    print "---------------------------------------------------------\n";
    return 1; #report success
}

sub testGridCert
{
    # check for grid-proxy-info command
    do {print "didn't find grid-proxy-info.... cannot check your certificate proxy\n";
	return 0;} if system("which grid-proxy-info >& /dev/null");
    
    # use it and grep for time left
    my $timeleft = `grid-proxy-info |grep timeleft`;
    do {print "no certificate proxy found.... perform a grid-proxy-init\n";
	print "---------------------------------------------------------\n";
	return 0} if !$timeleft;
    my $timeout = grep(m|0.0 days|,$timeleft);
    do {print "certificate proxy timed out.... perform a new grid-proxy-init\n";
	print "---------------------------------------------------------\n";
	return 0} if $timeout;
    
    print "Grid certificate available and valid proxy found\n";
    print "---------------------------------------------------------\n";
    return 1; # report success
}


sub testPOOLSetup
{
    my ($cat) = @_;
    # check availability of FC POOL tools
    do {print "didn't find FClistPFN... probably no POOL tools installed\n";
	print "---------------------------------------------------------\n";
	return 0;} if system("which FClistPFN >& /dev/null");
    
    #next try to access the MySQL POOL catalogue
    my $cmd ="FClistLFN -u $cat -q \"guid=\'123456\'\"";
    do {print "simple dummy query didn't succeed. Please check your POOL installation\n";
	print "command isued: \n";
	print "----------------------------------------------------------------------\n";
	return 0;} if system("$cmd >& /dev/null");


    print "POOL FC tools available and successfully tested\n";
    print "---------------------------------------------------------\n";
    return 1; # report success
}
