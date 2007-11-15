package PHEDEX::BlockConsistency::Injector::Agent;

=head1 NAME

PHEDEX::BlockConsistency::Injector::Agent - the Block Consistency Checking Injection agent.

=head1 SYNOPSIS

This implements the Injection agent for the Block Consistency Checking project.
See L<https://twiki.cern.ch/twiki/bin/view/CMS/PhedexProjConsistency> for
details.

=head1 DESCRIPTION

See the wiki, where the documentation is maintained.

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Agent';

use File::Path;
use Data::Dumper;
use PHEDEX::Core::Command;
use PHEDEX::Core::Logging;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::DB;
use PHEDEX::BlockConsistency::Core;

our $counter;
our $debug_me=1;
our %params =
	(
	  DBCONFIG => undef,		# Database configuration file
	  NODES => undef,		# Nodes to run this agent for
	  DROPBOX => undef,		# Directory for drops
	  IGNORE_NODES => [],		# TMDB nodes to ignore
	  ACCEPT_NODES => [],		# TMDB nodes to accept
	  WAITTIME => 3600 + rand(15),	# Agent activity cycle
	  CHECK_INTERVAL => 3 * 86400,	# Age to start checking...
	  LAST_CHECKED => 0,		# Internal lower bound
	  USE_SRM => 0,			# Use SRM instead of direct?
	);
    

sub daemon
{
  my $self = shift;
  if ( defined($main::Interactive) && $main::Interactive )
  {
    print "Stub the daemon() call\n";

#   Can't do this, because daemon is called from the base class, before
#   the rest of me is initialised. Hence the messing around...
#   $self->{WAITTIME} = 2;
    my $x = ref $self;
    no strict 'refs';
    ${$x . '::params'}{WAITTIME} = 2;
    return;
  }

  $self->SUPER::daemon(@_);
}

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = ref($proto) ? $class->SUPER::new(@_) : {};

  my %args = (@_);
  map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
      } keys %params;
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
  die "AUTOLOAD: Invalid attribute method: ->$attr()\n";
}

# Get a list of pending requests
sub stuckOnWan
{
  my ($self, $dbh, $filter, $filter_args) = @_;
  my (@requests,$sql,%p,$q);
  my ($now,$t,$interval);

  print scalar localtime, ": find candidates stuckOnWan: starting\n";
  $now = &mytimeofday();

# Blocks stuck over a link for longer than $interval, but not if already seen
  $sql = qq { select time_request, time_update,
                     ns.name sname, nd.name dname, bp.block block,
                     ns.id sid, nd.id did, b.name bname, l.is_local is_local
               from t_status_block_path bp
               join t_adm_node ns on ns.id = bp.src_node
               join t_adm_node nd on nd.id = bp.destination
               join t_adm_link l on l.from_node = bp.src_node
                                and l.to_node = bp.destination
               join t_dps_block b on b.id = bp.block
               where bp.is_valid = 1
                 and time_request <= :interval
                 and time_request > :last_checked
		 ${filter}
		order by time_request asc
       };
  $t = time();
  $interval = $t - $self->{CHECK_INTERVAL};
  print 'Search between ', (scalar localtime $interval), ' and ', (scalar localtime $self->{LAST_CHECKED}), "\n";
  %p = ( ":interval"     => $interval,
	 ":last_checked" => $self->{LAST_CHECKED},
	 %{$filter_args}
       );
  $q = &dbexec($dbh,$sql,%p);

  while ( my $h = $q->fetchrow_hashref() ) { push @requests, $h; }

  $self->{LAST_CHECKED} = $t;
  print scalar localtime,": Found ",scalar @requests," requests in total\n";
  return @requests;
}

# Pick up work from the database.
sub idle
{
  my ($self, @pending) = @_;
  my ($dbh,@nodes);

  eval
  {
    ($dbh,@nodes) = &expandNodesAndConnect($self);
    my ($filter, %filter_args) = &otherNodeFilter ($self, "nd.id");

#   first, some cleanup...
    my @r = @{PHEDEX::BlockConsistency::Core::getObsoleteTests( $self )}[0..29];
    PHEDEX::BlockConsistency::Core::clearTestDetails( $self, @r );
    $self->{DBH}->commit;

    $counter = 0;
#   Get a list of requests to process
    foreach my $request ($self->stuckOnWan ($dbh, $filter, \%filter_args))
    {
# Create an injection drop for the BDV agent!
      my %p = (
		BLOCK		=> $request->{BLOCK},
		N_FILES		=> 0,
		PRIORITY	=> 1024*1024*1024, # Pretty high priority!
		TEST		=> undef,
		TIME_EXPIRE	=> time() + 3 * 86400,
		NODE		=> undef,
		USE_SRM		=> $self->{USE_SRM} ? 'y' : 'n',
	      );

      if ( $request->{IS_LOCAL} eq 'y' )
      {
#       For LAN transfers, check migration at the destination.
        $p{TEST} = 'migration';
        $p{NODE} = $request->{DID};
        $p{NODE_NAME} = $request->{DNAME};
      }
      if ( $request->{IS_LOCAL} eq 'n' )
      {
#       For WAN transfers, check filesize at the source
        $p{TEST} = 'size';
        $p{NODE} = $request->{SID};
        $p{NODE_NAME} = $request->{SNAME};
      }
      next unless exists($self->{NODES_ID}{$p{NODE_NAME}});

      if ( defined($self->{DROPBOX}) )
      {
#       If I want to create dropboxes, call startOne...
        $p{INJECT_ONLY} = 1;
        $p{COMMENT} =
		{
		  BNAME => $request->{BNAME},
		  SNAME => $request->{SNAME},
		  DNAME => $request->{DNAME},
		  TIME_REQUEST => scalar localtime $request->{TIME_REQUEST},
		  TIME_UPDATE  => ( $request->{TIME_UPDATE} ?
				    scalar localtime $request->{TIME_UPDATE} :
				    undef ),
		};
        $self->startOne ( \%p );
      } 
      else
      {
#       ...otherwise, inject the test directly:
        delete $p{NODE_NAME};
        PHEDEX::BlockConsistency::Core::InjectTest( $self, %p );
      }
    }
    print scalar localtime, ": Started $counter requests\n";
    $dbh->commit();
  };
  do { chomp ($@);
      &alert ("database error: $@");
       eval { $dbh->rollback() } if $dbh
     } if $@;

  # Disconnect from the database
  &disconnectFromDatabase ($self, $dbh);

  # Have a little nap
# print scalar localtime,": idle: sleep until ",scalar localtime(time+$self->{WAITTIME}),"\n";
  $self->nap ($$self{WAITTIME});
}


#===========================================================================
sub dropBoxName
{
# Derive a dropbox name for a request. Required to be alphabetically
# sorted to the same order that the requests should be processed in.
  my ($self,$request) = @_;
  my $b = sprintf("%08x_%08x_%010d",
                   $request->{PRIORITY},
                   $request->{TIME_EXPIRE},
                   $counter++
                 );
  return $b;
}

sub startOne
{
  my ($self, $request) = @_;

  return 1 unless $self->{DROPBOX};

# Create a pending drop in the required location
  my $drop = $self->{DROPBOX} . '/' . $self->dropBoxName($request);
  do { &alert ("$drop already exists"); return 0; } if -d $drop;
  do { &alert ("failed to submit $$request{ID}"); &rmtree ($drop); return 0; }
        if (! &mkpath ($drop)
          || ! &output ("$drop/packet", Dumper ($request))
          || ! &touch ("$drop/go.pending"));

# OK, kick it go
  return 1 if &mv ("$drop/go.pending", "$drop/go");
  &warn ("failed to mark $$request{ID} ready to go");
  return 0;
}

1;
