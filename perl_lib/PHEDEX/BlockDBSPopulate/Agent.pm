package PHEDEX::BlockDBSPopulate::Agent;

=head1 NAME

PHEDEX::BlockDBSPopulate::Agent - the Block DBS Populate agent.

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::BlockDBSPopulate::SQL', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;
use PHEDEX::BlockConsistency::Core;
use DB_File;

our %params =
	(
	  DBCONFIG => undef,		# Database configuration file
	  WAITTIME => 600,		# Agent activity cycle
	  NODES => undef,  	        # Nodes this agent runs for, default all
          MIGR_COMMAND => undef,	# Migrate command
	  DEL_COMMAND => undef,		# DBS Invalidate command
          TARGET_DBS => undef,          # Target DBS
	  DUMMY => 0			# Test purpose
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
    $dbh = $self->connectAgent();
    my @nodes = $self->expandNodes();
    my @nodefilter = $self->myNodeFilter ("n.id");
    unless (@nodes) { die("Cannot find nodes in database for '@{$$self{NODES}}'") };

    # Get order list of blocks we have.  This is always everything,
    # but we keep track of what we've updated in a file.  If the
    # agent is started without the file existing it will try to
    # update everything.
    # Downstream users of this information must handle duplicates.
    my $completed = $self->getCompleted(@nodefilter);
    my $deleted   = $self->getDeleted(@nodefilter);

    # Get the ID for DBS test-requests from the t_dvs_test table.
    my $test = PHEDEX::BlockConsistency::SQL::get_TDVS_Tests($self,'dbs')->{ID};

    foreach my $block (@$deleted,@$completed)
    {
      # If we've updated already, skip this
      my $cachekey = "$block->{DBS_NAME} $self->{TARGET_DBS} $block->{DATASET_NAME} $block->{BLOCK_NAME} $block->{NODE_NAME}";
      next if exists $state{$cachekey} && $state{$cachekey} > 0;
      $state{$cachekey} = -1;

      # Queue the block for consistency-checking. Ignore return values

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
      

      # Now modify target DBS. If the command fails, alert but
      # keep going.
      my $log = "$self->{DROPDIR}$block->{SE_NAME}.$block->{BLOCK_ID}.log";
      my @cmd = ();

      if ( $block->{COMMAND} eq 'migrateBlock' )
      {
        @cmd = ($self->{MIGR_COMMAND}, "-s", $block->{DBS_NAME}, "-t", $self->{TARGET_DBS}, "-d", $block->{DATASET_NAME}, "-b", $block->{BLOCK_NAME}, "-a", $block->{SE_NAME}, "-c");
      }
      elsif ( $block->{COMMAND} eq 'deleteBlock' )
      {
        @cmd = ($self->{DEL_COMMAND}, "-u", $self->{TARGET_DBS}, "-b", $block->{BLOCK_NAME});
      }
      else { die("Command not supported: $block->{COMMAND}") }

      if ( defined $self->{DUMMY} )
      {
        if ( $self->{DUMMY} ) { unshift @cmd,'/bin/false'; }
        else                  { unshift @cmd,'/bin/true'; }
      }
      $self->addJob(sub { $self->registered ($block, \%state, $cachekey, @_) },
	          { TIMEOUT => 600, LOGFILE => $log },
	          @cmd);
      
    }
  };
  do { chomp ($@); $self->Alert ("database error: $@");
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
}

# Handle finished jobs.
sub registered
{
    my ($self, $block, $state, $cachekey, $job) = @_;

    if ($job->{STATUS_CODE} == 0)
    {
        $self->Logmsg("Successfully issued $block->{COMMAND}"
                . " on block $block->{BLOCK_NAME} for $block->{NODE_NAME}");
        unlink ($job->{LOGFILE});
        if ( $block->{COMMAND} eq 'migrateBlock' ) { $state->{$cachekey} = &mytimeofday(); }
        elsif ( $block->{COMMAND} eq 'deleteBlock' ) { delete $state->{$cachekey} if exists $state->{$cachekey}; }
        else { die("Command not supported: $block->{COMMAND}") }
    }
    else
    {
	$self->Warn("failed to $block->{COMMAND} block $block->{BLOCK_NAME} for"
	      . " $block->{NODE_NAME}, log in $job->{LOGFILE}");
    }
}

sub isInvalid
{
  my $self = shift;
  my $errors = $self->SUPER::isInvalid
                (
                  REQUIRED => [ qw / DROPDIR DBCONFIG NODES MIGR_COMMAND TARGET_DBS / ],
                );
  return $errors;
}

1;
