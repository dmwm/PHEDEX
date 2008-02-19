package PHEDEX::BlockMonitor::Agent;

=head1 NAME

PHEDEX::BlockMonitor::Agent - the Block Monitor agent.

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::BlockMonitor::SQL';
use PHEDEX::Core::Logging;
use PHEDEX::Core::Timing;

our %params =
	(
	  MYNODE    => undef,           # my TMDB nodename
    	  DBCONFIG  => undef,		# Database configuration file
	  WAITTIME  => 120 + rand(30),	# Agent cycle time
	  DUMMY     => 0,		# Dummy the updates
	  BLOCK_LIMIT => 5000,		# Number of blocks to process at once (memory safeguard)

	 VERBOSE	=> 0,
	 DEBUG		=> 0,
	 TERSE		=> 0
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

sub limitCheck
{
  my ($reason, $b, $ref) = @_;
  $ref ||= $b;
  $reason = "$reason $b->{BLOCK} at node $b->{NODE}";

  &alert("$reason destined $b->{DEST_FILES} files,"
            . " more than expected ($ref->{FILES})")
	if $b->{DEST_FILES} > $ref->{FILES};
  &alert("$reason destined $b->{DEST_BYTES} bytes,"
	    . " more than expected ($ref->{BYTES})")
	if $b->{DEST_BYTES} > $ref->{BYTES};
  &alert("$reason originated $b->{SRC_FILES} files,"
	    . " more than expected ($ref->{FILES})")
	if $b->{SRC_FILES} > $ref->{FILES};
  &alert("$reason originated $b->{SRC_BYTES} bytes,"
	    . " more than expected ($ref->{BYTES})")
	if $b->{SRC_BYTES} > $ref->{BYTES};
  &alert("$reason has $b->{NODE_FILES} files,"
	    . " more than expected ($ref->{FILES})")
	if $b->{NODE_FILES} > $ref->{FILES};
  &alert("$reason has $b->{NODE_BYTES} bytes,"
	    . " more than expected ($ref->{BYTES})")
	if $b->{NODE_BYTES} > $ref->{BYTES};
  &alert("$reason transferring $b->{XFER_FILES} files,"
	    . " more than expected ($ref->{FILES})")
	if $b->{XFER_FILES} > $ref->{FILES};
  &alert("$reason transferring $b->{XFER_BYTES} bytes,"
	    . " more than expected ($ref->{BYTES})")
	if $b->{XFER_BYTES} > $ref->{BYTES};
}

# Update statistics.
sub idle
{
    my ($self, @pending) = @_;
    my $dbh = undef;

    eval
    {
	$dbh = &connectToDatabase ($self);

	# Read existing block replica information.
	my $now = &mytimeofday ();

	my ($h,$qexisting,$row,$qactive,$q);
	my ($min_block, $max_block) = (0, 0);
	while ( (($min_block, $max_block) = $self->getBlockIDRange($self->{BLOCK_LIMIT}, $min_block))
		&& defined $max_block ) 
	{
	    &dbgmsg ("Block ID range $min_block to $max_block has up to ",
		     "$self->{BLOCK_LIMIT} blocks") if $self->{DEBUG};

	    # Guarantee full consistency.  We need to ensure that a) this
	    # procedure is aborted if someone goes and makes block open
	    # again and adds more files, b) we delete exactly as many
	    # t_xfer_replica rows as we planned to.
	    &dbexec ($dbh, q{set transaction isolation level serializable});

	    my (%replicas,%active);
	    ($qexisting,$h) = $self->getExistingReplicaInfo
		(
		 MIN_BLOCK => $min_block,
		 MAX_BLOCK => $max_block
		 );
	    &dbgmsg ("Retrieved $h->{N_REPLICAS} replicas up to block ID $h->{MAX_BLOCK}") if $self->{DEBUG};

	    while ( $row = shift @{$qexisting} )
	    {
		$replicas{$row->{BLOCK}}{$row->{NODE}} = $row;
		&limitCheck ("existing block", $row);
	    }

	    # Get file counts in currently active files: those destined at
	    # nodes, those at the nodes, and those in transfer to nodes.
	    # Note that file replicas at intermediate nodes show up as
	    # partial block replicas, so it's important that replicas at
	    # those nodes are either not cleaned at all, or cleaners clear
	    # at least some files before all destinations are completed.
	    # We consider the blocks alive even if all replicas are complete
	    # and there are no transfers, but there are pending destination
	    # assignments -- that just means file routing hasn't started.
	    #
	    # The actual data gathering is split into three separate queries
	    # and post-processing pass to reset undefined counters to zero.
	    # This avoids a single very expensive query -- the turnaround
	    # from several queries is much lower.  Still, we don't want this
	    # executed too often.
	    $qactive = $self->getDestFilesNBytes( $h );

	    while ( $q = shift @{$qactive} )
	    {
		map { $active{$q->{BLOCK}}{$q->{NODE}}{$_} = $q->{$_} } keys %{$q};
	    }

	    $qactive = $self->getSrcFilesNBytes( $h );
	    while ( $q = shift @{$qactive} )
	    {
		map { $active{$q->{BLOCK}}{$q->{NODE}}{$_} = $q->{$_} } keys %{$q};
	    }

	    $qactive = $self->getNodeFilesNBytes( $h );
	    while ( $q = shift @{$qactive} )
	    {
		map { $active{$q->{BLOCK}}{$q->{NODE}}{$_} = $q->{$_} } keys %{$q};
	    }

	    $qactive = $self->getXferFilesNBytes( $h );
	    while ( $q = shift @{$qactive} )
	    {
		map { $active{$q->{BLOCK}}{$q->{NODE}}{$_} = $q->{$_} } keys %{$q};
	    }

	    foreach my $b (map { values %$_ } values %active)
	    {
		$b->{DEST_FILES} ||= 0; $b->{DEST_BYTES} ||= 0;
		$b->{SRC_FILES}  ||= 0; $b->{SRC_BYTES}  ||= 0;
		$b->{NODE_FILES} ||= 0; $b->{NODE_BYTES} ||= 0;
		$b->{XFER_FILES} ||= 0; $b->{XFER_BYTES} ||= 0;

		if ($b->{NODE_FILES} == 0 &&
		    $b->{DEST_FILES} == 0 &&
		    $b->{XFER_FILES} == 0) {
		    $b->{EMPTY_SOURCE} = 1;
		} else {
		    $b->{EMPTY_SOURCE} = 0;
		}
	    }

	    # Compare differences I: start from previous replicas.
	    foreach my $b (map { values %$_ } values %replicas)
	    {
		# Check consistency of inactive blocks before ignoring
		# them: they can't be open or have active replicas or
		# transfers.  Count block active if it has active
		# file replicas or transfers; destinations alone do
		# not make a block active.
		if ($$b{IS_ACTIVE} ne 'y')
		{
		    &alert ("$b->{BLOCK} at $b->{NODE} inactive but open")
			if $b->{IS_OPEN} eq 'y';
		    &alert ("$b->{BLOCK} at $b->{NODE} inactive but active")
			if (exists $active{$b->{BLOCK}}{$b->{NODE}}
			    && ($active{$b->{BLOCK}}{$b->{NODE}}{NODE_FILES}
				|| $active{$b->{BLOCK}}{$b->{NODE}}{XFER_FILES}));
		    next;
		}

		# Remove obsolete replicas.  This inludes replicas for
		# source nodes which have since deleted their files and
		# they are not trying to transfer them back
		if (! exists $active{$b->{BLOCK}}{$b->{NODE}}
		    || $active{$b->{BLOCK}}{$b->{NODE}}{EMPTY_SOURCE} )
		{
		    &logmsg ("removing block $b->{BLOCK} at node $b->{NODE}");
		    $self->removeBlockAtNode( $b ) unless $self->{DUMMY};
		    next;
		}

		# Update statistics for active blocks
		my $new = $active{$b->{BLOCK}}{$b->{NODE}};
		if ($b->{DEST_FILES} != $new->{DEST_FILES}
		    || $b->{DEST_BYTES} != $new->{DEST_BYTES}
		    || $b->{SRC_FILES}  != $new->{SRC_FILES}
		    || $b->{SRC_BYTES}  != $new->{SRC_BYTES}
		    || $b->{NODE_FILES} != $new->{NODE_FILES}
		    || $b->{NODE_BYTES} != $new->{NODE_BYTES}
		    || $b->{XFER_FILES} != $new->{XFER_FILES}
		    || $b->{XFER_BYTES} != $new->{XFER_BYTES})
		{
		    &limitCheck ("updated block", $new, $b);
		    &logmsg ("updating block $b->{BLOCK} at node $b->{NODE}");
		    $self->updateBlockAtNode( NOW => $now, %{$new} )
			unless $self->{DUMMY};
		}
	    }

	    # Compare differences II: new ones.
	    foreach my $b (map { values %$_ } values %active)
	    {
		if (exists $replicas{$b->{BLOCK}}{$b->{NODE}} 
		    || $b->{EMPTY_SOURCE})
		{
		    # Already handled above
		    next;
		}
		elsif (grep ($_->{IS_ACTIVE} ne 'y', values %{$replicas{$b->{BLOCK}}}))
		{
		    # This block has inactive replicas.  Make sure all the
		    # replicas are inactive, then make sure this new replica
		    # has nothing but destinations defined (everything else
		    # is a consistency failure), and wait for BlockActivate
		    # to reactivate the block.
		    if (grep ($_->{IS_ACTIVE} eq 'y', values %{$replicas{$b->{BLOCK}}}))
		    {
			&alert ("block $b->{BLOCK} has inactive and active replicas");
		    }
		    elsif ($b->{NODE_FILES} || $b->{XFER_FILES})
		    {
			&alert ("block $b->{BLOCK} at node $b->{NODE} is active but the"
				. " block is otherwise inactive");
		    }
		    else
		    {
			&logmsg ("block $b->{BLOCK} is inactive with new destinations"
				 . " for node $b->{NODE}, waiting for activation");
		    }
		    next;
		}

		&logmsg ("creating block $b->{BLOCK} at node $b->{NODE}");
		$self->createBlockAtNode( NOW => $now, %{$b} )
		    unless $self->{DUMMY};
	    }

	    # Commit and iterate
	    $self->execute_commit();
	    $min_block = $max_block + 1;
	}
    };
    do { chomp ($@); &alert ("database error: $@");
	 eval { $self->execute_rollback() } if $dbh } if $@;

    # Disconnect from the database.
    &disconnectFromDatabase ($self, $dbh);
}

sub isInvalid
{
    my $self = shift;
    my $errors = $self->SUPER::isInvalid
	(
	 REQUIRED => [ qw / MYNODE DROPDIR DBCONFIG / ],
	 );
    if ( defined($self->{BLOCK_LIMIT}) && $self->{BLOCK_LIMIT} < 1000 )
    {
	$errors++;
	print __PACKAGE__,": BLOCK_LIMIT < 1000 is nuts, forget it...\n";
    }
    return $errors;
}

1;
