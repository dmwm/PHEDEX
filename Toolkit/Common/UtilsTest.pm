package UtilsTest; use strict; use warnings; use base 'Exporter';
use UtilsDB;
use UtilsLogging;
use UtilsCommand;
use UtilsTiming;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %args = (@_);
    my $me = $0; $me =~ s|.*/||;
    my %vals = (
		ME => $me,
		DBCONFIG => undef,
		DURATION => 60,
		PERIOD => 1,
		WORKDIR => undef);
    while (my ($k, $v) = each %vals) { $self->{$k} = $v }
    bless $self, $class;
    
    # FIXME: Would be good to check/create necessary dirs here
    # (See UtilsAgent)
    
    return $self;
}

# This is the main test management routine- will there be times when we
# need to override this??
sub process 
{
    my $self = shift;
    my $start = &mytimeofday();
    my $elapsed = 0;

    while( $elapsed < $self->{DURATION} ) 
    {    
        my $loopStart = time();

	$self->doTestTasks();
	
        if ( (&mytimeofday() - $loopStart) > $self->{PERIOD} ) 
	{ 
	    &alert( "Test is taking longer than your test cycle period!" ); 
	} else { 
	    sleep( $self->{PERIOD} - time() + $loopStart ); 
	}
	
	$elapsed = &mytimeofday() - $start;
    }
}

sub doTestTasks
{
    my $self = shift;
    my $dbh = undef;

    $dbh = &connectToDatabase ($self);
    eval {
	$self->checkLogs( $dbh );
	$self->test( $dbh );
    };
    if ( $@ ) {
	chomp ($@);
	&alert ("Problem in test loop: $@");
    }
    &disconnectFromDatabase($self, $dbh, 1);
}

sub checkLogs {
    my ($self, $dbh) = @_;
    my $logDir = "$self->{WORKDIR}/logs";
    my @files = ();
    my @triggers = ( "alert",
		     "Use of uninitialized value",
		     "unique constraint"
		     );
    
    &getdir( $logDir, \@files );

    # Here we examine log file entries made since the last test iteration. For
    # each file we check for each of the triggers listed in @triggers. Each log
    # file is cached as last-<file> for comparison in the next iteration
    foreach my $file ( @files )
    {
	if ( ! $file =~ /^last-/ )
	{
	    open( FILE, "$logDir/$file" );
	    my @diff = diff(  "$logDir/$file", "$logDir/last-$file" );
	    foreach ( @diff )
	    {
		foreach my $trigger ( @triggers ) 
		{
		    if ( /$trigger/ )
		    {
			&logmsg( "Problem in $file log\n$_" );
		    }
		}
	    }
	    close(FILE);
	    system( "rm $logDir/last-$file; cat $logDir/$file > $logDir/last-$file" );
	}
    }
}

print STDERR "WARNING:  use of Common/UtilsTest.pm is depreciated.  Update your code to use the PHEDEX perl library!\n";
1;
