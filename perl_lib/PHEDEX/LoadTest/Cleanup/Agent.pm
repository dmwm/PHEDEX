package PHEDEX::LoadTest::Cleanup::Agent;
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
		  MYNODE => undef,		# My TMDB node
		  ONCE => 0,			# Quit after one run
		  WAITTIME => 3600 );	        # Agent cycle time
    my %args = (@_);
    map { $$self{$_} = $args{$_} || $params{$_} } keys %params;
    bless $self, $class;
    return $self;
}

# Called by agent main routine before sleeping.  Do some work.
sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;

    eval
    {
	$dbh = $self->connectAgent();

	# Select deactivated blocks we can clean up.  Lock the block
	# row for transactional consistency
	my $qdel = &dbexec($dbh,
	  qq{ select b.id, b.name from t_dps_block b
                join t_dps_dataset ds on ds.id = b.dataset
                join t_loadtest_param lp on lp.dest_dataset = ds.id
                where ds.is_transient = 'y'
                  and b.is_open = 'n'
		  and exists (select 1 from t_dps_block_replica br
			       where br.block = b.id)
                  and not exists (select 1 from t_dps_block_replica br
                                   where br.block = b.id
                                    and br.is_active = 'y')
               for update
	     });

	# Iterate through the blocks deleting the files and blocks
	while (my ($id, $name) = $qdel->fetchrow()) {
	    my ($fdel, $nfiles) = &dbexec($dbh, qq{
              delete from t_dps_file where inblock = :block
	      }, ':block' => $id);

            my ($bdel, $nblocks) = &dbexec($dbh, qq{
              delete from t_dps_block where id = :block
              }, ':block' => $id);
    
	    $self->Logmsg("removing $name : $nfiles files");
	}
	
    	$dbh->commit();

    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh; } if $@;

    # Disconnect from the database
    $self->disconnectAgent();

    $self->doStop() if $$self{ONCE};
}

1;
