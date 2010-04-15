package PHEDEX::BlockActivate::Agent;

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::BlockActivate::SQL', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;

our %params =
	(
	  MYNODE => undef,              # my TMDB nodename
    	  DBCONFIG => undef,		# Database configuration file
	  WAITTIME => 600 + rand(100)	# Agent cycle time
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my $self = $class->SUPER::new(%params,@_);

  bless $self, $class;
  return $self;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

# Pick up work from the database and start site specific scripts if necessary
sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;

    eval
    {
	$dbh = $self->connectAgent();

	# Reactivate blocks with incomplete destinations or which
	# have been explicitly requested to be activated or deleted
	my $now = &mytimeofday ();
        my $g = $self->getBlockReactivationCandidates( NOW => $now );
	foreach my $h ( @{$g} )
        {
	    my $id        = $h->{ID};
	    my $block     = $h->{NAME};
	    my $nreplica  = $h->{NREPLICA};
	    my $nactive   = $h->{NACTIVE};
	    my $nempty    = $h->{NEMPTY};

	    # Ignore active blocks
	    if ($nactive)
	    {
	        next;
	    }

	    # Inactive and wanted.  Activate the file replicas.  However
	    # before we start, lock the block and check counts again in
	    # case something changes.
	    if ( ! $self->getLockForUpdateWithCheck
			(
			  ID        => $id,
			  NREPLICA  => $nreplica,
			  NACTIVE   => $nactive,
			  NEMPTY    => $nempty,
			) )
	    {
		$self->Warn ("block $id ($block) changed, skipping activation");
	        $dbh->rollback();
		next;
	    }

	    # Proceed to activate.
	    my ($files, $filereps, $nsetactive) = $self->activateBlock
					(
					  ID  => $id,
					  NOW => $now
					);

	    # Check that the activation did what we hoped
	    my $activated = $nreplica - $nempty;
	    if ( $activated * $files != $filereps ) {
		$self->Alert("inconsistency while activating block $id ($block): ".
			     "$activated block replicas activated * $files files != ".
			     "$filereps file replicas created, rolling back");
		$dbh->rollback();
		next;
	    }

	    # OK, it worked.  Now commit
	    $self->Logmsg ("block $id ($block) reactivated with $files files ".
			   "and $filereps replicas");
	    $dbh->commit();
	}

	# Remove old activation requests
        $self->removeOldActivationRequests( NOW => $now );
    };
    do { chomp ($@); $self->Alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh } if $@;

    # Disconnect from the database
    $self->disconnectAgent();
}

sub isInvalid
{
  my $self = shift;
  my $errors = $self->SUPER::isInvalid
                (
                  REQUIRED => [ qw / MYNODE DROPDIR DBCONFIG / ],
                );
  return $errors;
}

1;
