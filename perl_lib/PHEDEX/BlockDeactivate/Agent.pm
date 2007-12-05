package PHEDEX::BlockDeactivate::Agent;

=head1 NAME

PHEDEX::BlockDeactivate::Agent - the Block Deactivation agent.

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::BlockDeactivate::SQL';
#use PHEDEX::Core::Logging;
use PHEDEX::Core::Timing qw / mytimeofday /;
#use PHEDEX::Core::DB;

our %params =
	(
	  DBCONFIG => undef,		# Database configuration file
	  MYNODE => undef,		# My TMDB node
	  WAITTIME => 600 + rand(100),	# Agent cycle period
	  HOLDOFF => 3*86400,           # Hold-off time for pruning
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

# Prepend my own default parameters to the arguments. This maintains the
# correct hierarchical order
  my $self = $class->SUPER::new(%params, @_);

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

# Run the main loop of this agent.
sub idle
{
  my ($self, @pending) = @_;
  my $dbh = undef;

  $self->maybeStop;
  $dbh = &connectToDatabase ($self);

  # Deactivate complete blocks.  Get all blocks whose all replicas
  # are complete and active.  First of all, ignore blocks where
  # replicas are already inactive.  Secondly, ignore all blocks
  # which have been touched "recently" to allow things to settle.
  #
  # Consider remaining (active) block replicas.  If all replicas
  # of a block have as many files as the block has, deactive the
  # block (and all replicas).  We also require for extra safety
  # that there can be no files in transfer, or export, and the
  # block is not scheduled for deletion
  #
  # We do *not* require that dest_files = node_files, as at file
  # source nodes dest_files is usually zero, and we still want
  # to deactivate.  This should be safe -- we deactivate a block
  # on intermediate node is if a) the entire block has already
  # reached all current destination nodes, b) either all or none
  # of the files have been removed in intermediate nodes, and
  # c) several days has passed like this.  It is unlikely that
  # all these criteria will be met simultaneously, and in any
  # case the fix is easy: reactivate the block.
  #
  # What we do here requires a great degree of transactinal
  # consistency.  For one, we don't want someone to open blocks
  # while we are deactiving them; this is prevented by locking
  # the t_dps_block row with "select .. for update" while operating
  # on it, a convention followed by all programs which modify
  # block table.  Secondly, we need to make sure we delete the
  # exact number of file replicas we expected to delete; if an
  # inconsitency is detected, we roll back the transcation.
  #
  # Change of loop logic with 2.5.4.2: Now we get the list of blocks which are
  # candidates for deactivation, then we go through the list one by one, lock
  # the block, check that it is still a candidate, then process it. This allows
  # us to process many blocks in one pass of the agent.
  #
  # This also means that the logic for stopping the agent has changed, there's
  # a call to maybeStop inside the loop, just in case it gets too busy, and
  # the eval has moved inside the loop too.
  my $limit = &mytimeofday () - $self->{HOLDOFF};
  my $qblocks = $self->getBlockDeactivationCandidates( LIMIT => $limit );
  my ($qb,$id,$name,$nfr,$b);
  foreach $qb ( @{$qblocks} )
  {
    eval
    {
      $id   = $qb->{ID};
      $name = $qb->{NAME};
      # Get the number of file replicas expected to delete.
      $b = $self->getBlockDeactivationCandidates
			(
			  BLOCK => $id,
			  LIMIT => $limit,
			  LOCK_FOR_UPDATE => 1,
			);
      goto DONE unless $b && ref($b) eq 'HASH';
      goto DONE unless $b->{ID} == $id && $b->{NAME} eq $name;
      $nfr = $self->nExpectedDeletions( BLOCK => $id );
      if (! $nfr)
      {
        &alert ("refusing to deactivate block $name with no files");
           $self->setBlockActive( BLOCK => $id );
        $dbh->commit();
      }
      else
      {
        # Deactivate.
        my $nr = $self->deactivateReplicas( BLOCK => $id );   
        if ($nr != $nfr)
        {
          &alert ("deactivating $name deleted $nr file replicas,"
	      . " expected to delete $nfr, undoing deactivation");
          $dbh->rollback();
        }
        else
        {
          my $nb = $self->setBlockInactive( BLOCK => $id );
          &logmsg ("deactivated $name: $nr file replicas, $nb block replicas");
          $dbh->commit ();
        }
      }
DONE:
      $self->maybeStop;
    };
    do { chomp ($@); &alert ("database error: $@");
      eval { $dbh->rollback() } if $dbh } if $@;
  }

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
