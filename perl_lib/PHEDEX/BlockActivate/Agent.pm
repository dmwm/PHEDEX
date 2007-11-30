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
use base 'PHEDEX::Core::Agent, PHEDEX::BlockActivate::SQL';
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

  my $self = $class->SUPER::new(@_);
  foreach ( keys %params )
  {
    $self->{$_} = $params{$_} unless defined $self->{$_};
  }

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
#        my $stmt = &dbexec ($dbh, qq{
#	    select b.id, b.name, count(br.block), sum(decode(br.is_active,'y',1,0))
#	    from t_dps_block b
#	      join t_dps_block_replica br
#	        on br.block = b.id
#	    where exists (select bd.block
#	    		  from t_dps_block_dest bd
#	    		  where bd.block = b.id
#			    and bd.state != 3)
#	       or exists (select bd.block
#       			  from t_dps_block_delete bd
#			  where bd.block = b.id and bd.time_complete is null)
#	       or exists (select ba.block
#       			  from t_dps_block_activate ba
#			  where ba.block = b.id
#			    and ba.time_request <= :now
#			    and (ba.time_until is null
#		    		 or ba.time_until >= :now))
#	    group by b.id, b.name},
#    	    ":now" => $now);
#	while (my ($id, $block, $nreplica, $nactive) = $stmt->fetchrow())
        my $h = $self->getBlockReactivationCandidates( NOW => $now);
	foreach my $id ( keys %{$h} )
        {
	    my $block    = $h->{$id}{NAME};
	    my $nreplica = $h->{$id}{NREPLICA};
	    my $nactive  = $h->{$id}{NACTIVE};
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
#	    &dbexec ($dbh, qq{
#		select * from t_dps_block where id = :block for update},
#		":block" => $id);
#
#	    my ($xnreplica, $xnactive) = &dbexec ($dbh, qq{
#		select count(block), sum(decode(br.is_active,'y',1,0))
#		from t_dps_block_replica br where br.block = :block},
#		":block" => $id)->fetchrow ();
#	    if ($xnactive != $nactive || $xnreplica != $nreplica)
	    if ( ! $self->getLockForUpdateWithCheck
			(
			  NOW      => $now,
			  NREPLICA => $nreplica,
			  NACTIVE  => $nactive,
			) )
	    {
		&warn ("block $id ($block) changed, skipping activation");
		next;
	    }

	    # Proceed to activate.
#	    my ($stmt, $nfile) = &dbexec ($dbh, qq{
#		insert into t_xfer_file
#		(id, inblock, logical_name, checksum, filesize)
#		(select id, inblock, logical_name, checksum, filesize
#		 from t_dps_file where inblock = :block)},
#		":block" => $id);
#
#	    my ($stmt2, $nreplica) = &dbexec ($dbh, qq{
#		insert into t_xfer_replica
#		(id, fileid, node, state, time_create, time_state)
#		(select seq_xfer_replica.nextval, f.id, br.node,
#		        0, br.time_create, :now
#		 from t_dps_block_replica br
#		 join t_xfer_file f on f.inblock = br.block
#		 where br.block = :block)},
#	   	 ":block" => $id, ":now" => $now);
#
#	    &dbexec ($dbh, qq{
#		update t_dps_block_replica
#		set is_active = 'y', time_update = :now
#		where block = :block},
#		":block" => $id, ":now" => $now);
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
#	&dbexec ($dbh, qq{
#	    delete from t_dps_block_activate
#	    where time_request < :now
#	      and time_until is not null
#	      and time_until < :now},
#           ":now" => $now);
        $self->removeOldActivationRequests( NOW => $now );
    };
    do { chomp ($@); &alert ("database error: $@");
	 eval { $dbh->rollback() } if $dbh } if $@;

    # Disconnect from the database
    &disconnectFromDatabase ($self, $dbh);

    # Have a little nap
    $self->nap ($$self{WAITTIME});
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
