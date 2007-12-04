package PHEDEX::BlockActivate::Agent;

=head1 NAME

PHEDEX::BlockActivate::Agent - the Block Activation agent.

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::BlockActivate::SQL';
use PHEDEX::Core::Logging;
use PHEDEX::Core::Timing;
use PHEDEX::Core::DB;

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
	$dbh = &connectToDatabase ($self);

	# Reactivate blocks with incomplete destinations or which
	# have been explicitly requested to be activated or deleted
	my $now = &mytimeofday ();
        my $g = $self->getBlockReactivationCandidates( NOW => $now );
	foreach my $h ( @{$g} )
        {
	    my $id       = $h->{ID};
	    my $block    = $h->{NAME};
	    my $nreplica = $h->{NREPLICA};
	    my $nactive  = $h->{NACTIVE};
	    # Ignore active blocks
	    if ($nactive)
	    {
		&alert ("block $id ($block) has $nreplica replicas"
			. " of which only $nactive are active")
		    if $nreplica != $nactive;
	        next;
	    }

	    # Inactive and wanted.  Activate the file replicas.  However
	    # before we start, lock the block and check counts again in
	    # case something changes.
	    if ( ! $self->getLockForUpdateWithCheck
			(
			  ID       => $id,
			  NREPLICA => $nreplica,
			  NACTIVE  => $nactive,
			) )
	    {
		&warn ("block $id ($block) changed, skipping activation");
	        $dbh->rollback();
		next;
	    }

	    # Proceed to activate.
	    my ($nfile,$nreplica) = $self->activateBlock
					(
					  ID  => $id,
					  NOW => $now
					);

	    &logmsg ("block $id ($block) reactivated with $nfile files"
		     . " and $nreplica replicas");
	    $dbh->commit();
	}

	# Remove old activation requests
        $self->removeOldActivationRequests( NOW => $now );
    };
    do { chomp ($@); &alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh } if $@;

    # Disconnect from the database
    &disconnectFromDatabase ($self, $dbh);

    # Have a little nap
    $self->nap ($self->{WAITTIME});
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
