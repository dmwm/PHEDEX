package PHEDEX::Monitoring::InfoFileSize::Agent;
use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    my %params = (DBCONFIG => undef,		# Database configuration file
		  MYNODE => undef,		# My TMDB node name
	    	  WAITTIME => 1200 + rand(200), # Agent activity cycle
		  ME	=> 'InfoFileSize',
		 );
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Called by agent main routine before sleeping.  Update database.
sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;
    eval
    {
	$dbh = $self->connectAgent();

	# Recreate statistics
	my $now = &mytimeofday();
	&dbexec($dbh, qq{delete from t_status_file_size_overview});
	&dbexec($dbh, qq{delete from t_status_file_size_histogram});
	&dbexec($dbh, qq{insert into t_status_file_size_overview
			(select
			   :now,
			   nvl(count(filesize),0),
		           nvl(sum(filesize),0),
		           nvl(min(filesize),0),
		           nvl(max(filesize),0),
	                   nvl(avg(filesize),0),
		           nvl(percentile_disc(.5) within group (order by filesize),0)
			 from t_dps_file)},
	        ":now" => $now);
	&dbexec($dbh, qq{insert into t_status_file_size_histogram
			(select
			   :now,
			   binsize,
			   10 * 1024 * 1024,
			   count(binsize),
			   sum(realsize)
			 from (select
			         trunc(filesize/(10 * 1024 * 1024)) as binsize,
				 filesize as realsize
			       from t_dps_file)
			 group by binsize)},
	        ":now" => $now);

	$dbh->commit();
    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database
    $self->disconnectAgent();
}

1;
