package UtilsTest; use strict; use warnings; use base 'Exporter';
use UtilsDB;
use UtilsLogging;

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
    
    my $start = time();
    while( time() - $start < $self->{DURATION} ) {    
        my $loopStart = time();
	
        my $dbh = undef; $dbh = &connectToDatabase ($self,0) or die "failed to connect";
        eval {
            $self->checkLogs( $dbh );  # These are automatic tests of the logs for alerts etc
            $self->test( $dbh );      # This is the custom, specific test
        };
        do { &alert ("Problem in test loop: $@") } if $@;
        $dbh->disconnect();

        if ( (time() - $loopStart) > $self->{PERIOD} ) {
            &alert( "Test is taking longer than your test cycle period!" );
        } else {
            sleep( $self->{PERIOD} - time() + $loopStart );
        }
    }
}

# Generic log checking
sub checkLogs {
    my ($self, $dbh) = @_;
    my $logDir = "$self->{WORKDIR}/logs";

    opendir( DIR, "$logDir" ) or die "Couldn't open log directory: $!";
    while( defined (my $file = readdir( DIR )) ) {
        open( FILE, "$logDir/$file" );
        if ( $file ne "." && $file ne ".." && ! $file =~ /^last-/ ) {
            system( "touch $logDir/last-$file" );
            open( FILE, "diff $logDir/$file $logDir/last-$file |" );
            while(<FILE>) {
                if (/alert/ 
                    || /Use of uninitialized value/
                    || /unique constraint/) {
                    &logmsg( "Problem in $file log" );
                    print "$_\n";
                }
            }
            system( "rm $logDir/last-$file" );
            system( "cat $logDir/$file > $logDir/last-$file" );
        }
        close( FILE );
    }
    close( DIR );
}

1;
