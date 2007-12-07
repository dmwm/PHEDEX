package PHEDEX::BlockDLSUpdate::Agent;

=head1 NAME

PHEDEX::BlockDLSUpdate::Agent - the Block DLS Update agent.

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::BlockDLSUpdate::SQL';
use PHEDEX::Core::Timing;
use PHEDEX::BlockConsistency::Core;
use DB_File;

our %params =
	(
	  DBCONFIG => undef,		# Database configuration file
	  WAITTIME => 3600,		# Agent activity cycle
	  NODES => undef,		# Nodes this agent runs for
	);
our @array_params = qw / NODES /;

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

# Pick up ready blocks from database and inform downstream agents.
sub idle
{
  my ($self, @pending) = @_;
  my $dbh;
  # tie state file
  my %state;
  tie %state, 'DB_File', "$self->{DROPDIR}/state.dbfile"
	or die "Could not tie state file:  $!\n";

  eval
  {
    # Connect to database
    my @nodes = ();
    ($dbh, @nodes) = &expandNodesAndConnect ($self);
    my @nodefilter = &myNodeFilter ($self, "br.node");

    # Get order list of blocks we have.  This is always everything,
    # but we keep track of what we've updated in a file.  If the
    # agent is started without the file existing it will try to
    # update everything.
    # Downstream users of this information must handle duplicates.
    my $completed = $self->getCompleted(@nodefilter);
    my $deleted   = $self->getDeleted(@nodefilter);

    # Get the ID for DBS test-requests from the t_dvs_test table.
    my $test = PHEDEX::BlockConsistency::SQL::get_TDVS_Tests($self,'dbs')->{ID};

    foreach my $block (@$completed, @$deleted)
    {
      # If we've updated already, skip this
      my $cachekey = "$block->{COMMAND} $block->{DBS_NAME} $block->{BLOCK_NAME} $block->{NODE_NAME}";
      next if exists $state{$cachekey} && $state{$cachekey} > 0;
      $state{$cachekey} = -1;

      # If it is a deletion command, remove addition command from cache
      if ( $block->{COMMAND} eq 'dls-delete')
      {
	my $addkey = $cachekey;
	$addkey =~ s/dls-delete/dls-add/;
	delete $state{$addkey} if exists $state{$addkey};
      }

      # Queue the block for consistency-checking. Ignore return values
      if ( $block->{COMMAND} eq 'dls-add' )
      {
        PHEDEX::BlockConsistency::Core::InjectTest
		( $dbh,
		  block       => $block->{BLOCK_ID},
		  test        => $test,
		  node        => $block->{NODE_ID},
		  n_files     => 0,
		  time_expire => 10 * 86400,
		  priority    => 1,
		  use_srm     => 'n',
		);
      }

      # Decompose DLS contact into arguments accepted by DLS API.
      my ($dlstype, $sep, $contact) = ($block->{DLS_NAME} =~ m|^([a-z]+)(://)?(.*)|);

      my $dls_iface;
      if ($dlstype eq 'lfc') { $dls_iface = 'DLS_TYPE_LFC'; }
      elsif ($dlstype eq 'mysql') { $dls_iface = 'DLS_TYPE_MYSQL'; }
      elsif ($dlstype eq 'dbs')
      { 
	  $dls_iface = 'DLS_TYPE_DBS';
	$contact = $block->{DBS_NAME} unless $contact;
      }
      else
      {
	&alert ("dls contact $block->{DLS_NAME} not understood");
	next;
      }

      # Now modify DLS.  If the command fails, alert but
      # keep going.
      my $log = "$self->{DROPDIR}/$block->{SE_NAME}.$block->{BLOCK_ID}.log";
      my @cmd = ("$block->{COMMAND}", "-i", $dls_iface,
	       "-e", $contact, $block->{BLOCK_NAME}, $block->{SE_NAME});

      if ( defined $self->{DUMMY} )
      {
        if ( $self->{DUMMY} ) { unshift @cmd,'/bin/false'; }
        else                  { unshift @cmd,'/bin/true'; }
      }
      $self->addJob(sub { $self->registered ($block, \$state{$cachekey}, @_) },
	          { TIMEOUT => 30, LOGFILE => $log },
	          @cmd);
    }
  };
  do { chomp ($@); &alert ("database error: $@");
    eval { $dbh->rollback() } if $dbh } if $@;

  # Disconnect from the database
  &disconnectFromDatabase ($self, $dbh, 1);

  # Wait for all jobs to finish
  while (@{$self->{JOBS}})
  {
      $self->pumpJobs();
      select (undef, undef, undef, 0.1);
  }

  # untie
  untie %state;

  # Have a little nap
  $self->nap ($self->{WAITTIME});
}

# Handle finished jobs.
sub registered
{
    my ($self, $block, $state, $job) = @_;
    if ($job->{STATUS})
    {
	&warn("failed to $block->{COMMAND} block $block->{BLOCK_NAME} for"
	      . " $block->{NODE_NAME}, log in $job->{LOGFILE}");
    }
    else
    {
	&logmsg("Successfully issued $block->{COMMAND}"
		. " on block $block->{BLOCK_NAME} for $block->{NODE_NAME}");
	unlink ($job->{LOGFILE});
	$$state = &mytimeofday();
    }
}

sub isInvalid
{
  my $self = shift;
  my $errors = $self->SUPER::isInvalid
                (
                  REQUIRED => [ qw / DROPDIR DBCONFIG / ],
                );
  return $errors;
}

1;
