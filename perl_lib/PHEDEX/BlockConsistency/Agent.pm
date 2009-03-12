package PHEDEX::BlockConsistency::Agent;

=head1 NAME

PHEDEX::BlockConsistency::Agent - the Block Consistency Checking agent.

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent>, 
L<PHEDEX::BlockConsistency::SQL|PHEDEX::BlockConsistency::SQL>.

=cut
use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::BlockConsistency::SQL', 'PHEDEX::Core::Logging';

use File::Path;
use File::Basename;
use Cwd;
use Data::Dumper;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Catalogue ( qw / storageRules dbStorageRules applyStorageRules / );
use PHEDEX::Core::DB;
use PHEDEX::BlockConsistency::Core;
use PHEDEX::Namespace;
use PHEDEX::Core::Loader;
use POE;
use POE::Queue::Array;

our %params =
	(
	  WAITTIME	=> 300 + rand(15),	# Agent activity cycle
	  PROTOCOL	=> 'direct',		# File access protocol
	  STORAGEMAP	=> undef,		# Storage path mapping rules
	  USE_SRM	=> 'n',			# Use SRM or native technology?
	  RFIO_USES_RFDIR => 0,			# Use rfdir instead of nsls?
	  PRELOAD	=> undef,		# Library to preload for dCache?
	  ME => 'BlockDownloadVerify',		# Name for the record...
	  NAMESPACE	=> undef,
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new(%params,@_);
  $self->{bcc} = PHEDEX::BlockConsistency::Core->new();
  $self->{QUEUE} = POE::Queue::Array->new();
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

sub doDBSCheck
{
  my ($self, $request) = @_;
  my ($n_files,$n_tested,$n_ok);
  my @nodes = ();

  $self->Logmsg("doDBSCheck: starting") if ( $self->{DEBUG} );
  $self->{bcc}->Checks($request->{TEST}) or
    die "Test $request->{TEST} not known to ",ref($self),"!\n";

  $self->Logmsg("doDBSCheck: Request ",$request->{ID}) if ( $self->{DEBUG} );
  $n_files = $request->{N_FILES};
  my $t = time;

# fork the dbs call and harvest the results
  my $d = dirname($0);
  if ( $d !~ m%^/% ) { $d = cwd() . '/' . $d; }
  my $dbs = $d . '/DBSgetLFNsFromBlock';
  my $r = $self->getDBSFromBlockIDs($request->{BLOCK});
  my $dbsurl = $r->[0] or die "Cannot get DBS url?\n";
  my $blockname = $self->getBlocksFromIDs($request->{BLOCK})->[0];

  open DBS, "$dbs --url $dbsurl --block $blockname |" or do
  {
    $self->Alert("$dbs: $!\n");
    return 0;
  };
  my %dbs;
  while ( <DBS> ) { if ( m%^LFN=(\S+)$% ) { $dbs{$1}++; } }
  close DBS or do
  {
    $self->Alert("$dbs: $!\n");
    return 0;
  };

  eval
  {
    $n_tested = $n_ok = 0;
    $n_files = $request->{N_FILES};
    foreach my $r ( @{$request->{LFNs}} )
    {
      if ( delete $dbs{$r->{LOGICAL_NAME}} ) { $r->{STATUS} = 'OK'; }
      else                                   { $r->{STATUS} = 'Error'; }
      $self->setFileState($request->{ID},$r);
      $n_tested++;
      $n_ok++ if $r->{STATUS} eq 'OK';
    }
    $n_files = $n_tested + scalar keys %dbs;
    $self->setRequestFilecount($request->{ID},$n_tested,$n_ok);
    if ( scalar keys %dbs )
    {
      die "Hmm, how to handle this...? DBS has more than TMDB!\n";
      $self->setRequestState($request,'Suspended');
    }
    if ( $n_files == 0 )
    {
      $self->setRequestState($request,'Indeterminate');
    }
    elsif ( $n_ok == $n_files )
    {
      $self->setRequestState($request,'OK');
    }
    elsif ( $n_tested == $n_files && $n_ok != $n_files )
    {
      $self->setRequestState($request,'Fail');
    }
    else
    {
      print "Hmm, what state should I set here? I have (n_files,n_ok,n_tested) = ($n_files,$n_ok,$n_tested) for request $request->{ID}\n";
    }
    $self->{DBH}->commit();
  };

  do
  {
    chomp ($@);
    $self->Alert ("database error: $@");
    eval { $self->{DBH}->rollback() };
    return 0;
  } if $@;
 
  my $status = ( $n_files == $n_ok ) ? 1 : 0;
  return $status;
}

sub doNSCheck
{
  my ($self, $request) = @_;
  my ($n_files,$n_tested,$n_ok);
  my ($ns,$loader,$cmd,$mapping);
  my @nodes = ();

  $self->Logmsg("doNSCheck: starting") if ( $self->{DEBUG} );

  $self->{bcc}->Checks($request->{TEST}) or
    die "Test $request->{TEST} not known to ",ref($self),"!\n";

  if ( $self->{STORAGEMAP} )
  {
    $mapping = storageRules( $self->{STORAGEMAP}, 'lfn-to-pfn' );
  }
  else
  {
    my $cats;
    my $nodeID = $self->{NODES_ID}{$self->{NODES}[0]};
    $mapping = dbStorageRules( $self->{DBH}, $cats, $nodeID );
  }

  if ( $self->{NAMESPACE} )
  {
    $loader = PHEDEX::Core::Loader->new( NAMESPACE => 'PHEDEX::Namespace' );
    $ns = $loader->Load($self->{NAMESPACE})->new();
    if ( $request->{TEST} eq 'size' )      { $cmd = 'size'; }
    if ( $request->{TEST} eq 'migration' ) { $cmd = 'is_migrated'; }
  }
  else
  {
    $ns = PHEDEX::Namespace->new
		(
			DBH		=> $self->{DBH},
			STORAGEMAP	=> $self->{STORAGEMAP},
			RFIO_USES_RFDIR	=> $self->{RFIO_USES_RFDIR},
			PRELOAD		=> $self->{PRELOAD},
		);
    if ( $request->{TEST} eq 'size' )        { $cmd = 'statsize'; }
    if ( $request->{TEST} eq 'migration' )   { $cmd = 'statmode'; }
    if ( $request->{TEST} eq 'is_migrated' ) { $cmd = 'statmode'; }

    if ( $self->{USE_SRM} eq 'y' or $request->{USE_SRM} eq 'y' )
    {
      $ns->protocol( 'srmv2' );
      $ns->TFCPROTOCOL( 'srmv2' );
    }
    else
    {
      my $technology = $self->{bcc}->Buffers(@{$self->{NODES}});
      $ns->technology( $technology );
    }
  }

  $self->Logmsg("doNSCheck: Request ",$request->{ID}) if ( $self->{DEBUG} );
  $n_files = $request->{N_FILES};
  my $t = time;
  foreach my $r ( @{$request->{LFNs}} )
  {
    no strict 'refs';
    my $pfn;
    my $tfcprotocol = 'direct';
    my $node = $self->{NODES}[0];
    my $lfn = $r->{LOGICAL_NAME};
    $pfn = &applyStorageRules($mapping,$tfcprotocol,$node,'pre',$lfn,'n');
    if ( $request->{TEST} eq 'size' )
    {
      my $size = $ns->$cmd($pfn);
      if ( defined($size) && $size == $r->{FILESIZE} ) { $r->{STATUS} = 'OK'; }
      else { $r->{STATUS} = 'Error'; }
    }
    elsif ( $request->{TEST} eq 'migration' ||
	    $request->{TEST} eq 'is_migrated' )
    {
      my $mode = $ns->$cmd($pfn);
      if ( defined($mode) && $mode ) { $r->{STATUS} = 'OK'; }
      else { $r->{STATUS} = 'Error'; }
    }
    $r->{TIME_REPORTED} = time();
    last unless --$n_files;
    if ( time - $t > 60 )
    {
      $self->Logmsg("$n_files files remaining") if ( $self->{DEBUG} );
      $t = time;
    }
  }

  eval
  {
    $n_tested = $n_ok = 0;
    $n_files = $request->{N_FILES};
    foreach my $r ( @{$request->{LFNs}} )
    {
      next unless $r->{STATUS};
      $self->setFileState($request->{ID},$r);
      $n_tested++;
      $n_ok++ if $r->{STATUS} eq 'OK';
    }
    $self->setRequestFilecount($request->{ID},$n_tested,$n_ok);
    if ( $n_files == 0 )
    {
      $self->setRequestState($request,'Indeterminate');
    }
    elsif ( $n_ok == $n_files )
    {
      $self->setRequestState($request,'OK');
    }
    elsif ( $n_tested == $n_files && $n_ok != $n_files )
    {
      $self->setRequestState($request,'Fail');
    }
    else
    {
      print "Hmm, what state should I set here? I have (n_files,n_ok,n_tested) = ($n_files,$n_ok,$n_tested) for request $request->{ID}\n";
    }
    $self->{DBH}->commit();
  };

  do
  {
    chomp ($@);
    $self->Alert ("database error: $@");
    eval { $self->{DBH}->rollback() };
    return 0;
  } if $@;
 
  my $status = ( $n_files == $n_ok ) ? 1 : 0;
  return $status;
}

sub _poe_init
{
  my ($self,$kernel) = @_[ OBJECT, KERNEL ];
  $kernel->state('do_tests',$self);
  $kernel->state('get_work',$self);
  $kernel->yield('do_tests');
}

sub do_tests
{
  my ($self, $kernel) = @_[ OBJECT, KERNEL ];
  my ($request,$r,$id,$priority);

  ($priority,$id,$request) = $self->{QUEUE}->dequeue_next();
  if ( ! $request )
  {
    $kernel->yield('get_work');
    return;
  }

  $self->{pmon}->State('do_tests','start');
# Sanity checking
  &timeStart($$self{STARTTIME});

  eval { $self->connectAgent(); };
  do {
       chomp ($@);
       $self->Alert ("database error: $@");
       return;
  } if $@;
  $self->{bcc}->DBH( $self->{DBH} );

  if ( $request->{TIME_EXPIRE} <= time() )
  {
    $self->setRequestState($request,'Expired');
    $self->{DBH}->commit();
    $self->Logmsg("do_tests: return after Expiring $request->{ID}");
  }

  if ( $request->{TEST} eq 'size' ||
       $request->{TEST} eq 'migration' ||
       $request->{TEST} eq 'is_migrated' )
  {
    $self->setRequestState($request,'Active');
    $self->{DBH}->commit();
    my $result = $self->doNSCheck ($request);
  }
  elsif ( $request->{TEST} eq 'dbs' )
  {
    $self->setRequestState($request,'Active');
    $self->{DBH}->commit();
    my $result = $self->doDBSCheck ($request);
  }
  else
  {
    $self->setRequestState($request,'Rejected');
    $self->{DBH}->commit();
    $self->Logmsg("do_tests: return after Rejecting $request->{ID}");
  }
  $self->{pmon}->State('do_tests','stop');
  $kernel->yield('do_tests');
}

# Get a list of pending requests
sub requestQueue
{
  my ($self, $limit, $mfilter, $mfilter_args, $ofilter, $ofilter_args) = @_;
  my (@requests,$sql,%p,$q,$q1,$n,$i);

  $self->Logmsg("requestQueue: starting") if ( $self->{DEBUG} );
  my $now = &mytimeofday();

# Find all the files that we are expected to work on
  $n = 0;

  $sql = qq{
		select b.id, block, n_files, time_expire, priority,
		name test, use_srm
		from t_dvs_block b join t_dvs_test t on b.test = t.id
		join t_status_block_verify v on b.id = v.id
		where ${$mfilter}
		and status = 0
		${$ofilter}
		order by priority asc, time_expire asc
       };
  %p = (  %{$mfilter_args}, %{$ofilter_args} );
  $q = &dbexec($self->{DBH},$sql,%p);

  $sql = qq{ select logical_name, checksum, filesize, vf.fileid,
		nvl(time_reported,0) time_reported, nvl(status,0) status
		from t_dps_file pf join t_dvs_file vf on vf.fileid = pf.id
		left join t_dvs_file_result vfr on vfr.fileid = vf.fileid
		where vf.request = :request
		order by fileid asc, time_reported desc
	   };
  while ( my $h = $q->fetchrow_hashref() )
  {
    %p = ( ':request' => $h->{ID} );
    $q1 = &dbexec($self->{DBH},$sql,%p);
    my %f;
    while ( my $g = $q1->fetchrow_hashref() )
    {
      $f{$g->{FILEID}} = $g unless exists( $f{$g->{FILEID}} );
    }
    @{$h->{LFNs}} = values %f;
    $n += scalar @{$h->{LFNs}};
    push @requests, $h;
    last if ++$i >= $limit;
  }

  $self->Logmsg("Got ",scalar @requests," requests, for $n files in total") if ( $n );
  return @requests;
}

# Pick up work from the database.
sub get_work
{
  my ($self, $kernel) = @_[ OBJECT, KERNEL ];
  my @nodes = ();

  $self->{pmon}->State('get_work','start');
  eval
  {
    $self->connectAgent();
    @nodes = $self->expandNodes();
    @nodes or die "No node found? Typo perhaps?\n";
    my ($mfilter, %mfilter_args) =    $self->myNodeFilter ("b.node");
    my ($ofilter, %ofilter_args) = $self->otherNodeFilter ("b.node");

#   Get a list of requests to process
    foreach my $request ($self->requestQueue(10, \$mfilter, \%mfilter_args,
						 \$ofilter, \%ofilter_args))
    {
      $self->{QUEUE}->enqueue($request->{PRIORITY},$request);
#     $self->setRequestState($request,'Queued');
    }
    $self->{DBH}->commit();
    if ( $self->{QUEUE}->get_item_count() ) { $kernel->yield('do_tests'); }
    else
    {
      $kernel->delay_set('get_work',$self->{WAITTIME});
      # Disconnect from the database
      $self->disconnectAgent();
    }
  };
  do {
     chomp ($@);
     $self->Alert ("database error: $@");
     $self->{DBH}->rollback();
  } if $@;
  $self->{pmon}->State('get_work','stop');

  return;
}

sub setFileState
{
# Change the state of a file-test in the database
  my ($self, $request, $result) = @_;
  my ($sql,%p,$q);
  return unless defined $result;

  $sql = qq{
	insert into t_dvs_file_result fr 
	(id,request,fileid,time_reported,status)
	values
	(seq_dvs_file_result.nextval,:request,:fileid,:time,
	 (select id from t_dvs_status where name like :status_name )
	)
       };
  %p = ( ':fileid'      => $result->{FILEID},
  	 ':request'     => $request,
         ':status_name' => $result->{STATUS},
         ':time'        => $result->{TIME_REPORTED},
       );
  $q = &dbexec($self->{DBH},$sql,%p);
}

sub setRequestFilecount
{
  my ($self,$id,$n_tested,$n_ok) = @_;
  my ($sql,%p,$q);

  $sql = qq{ update t_status_block_verify set n_tested = :n_tested,
		n_ok = :n_ok where id = :id };
  %p = ( ':n_tested' => $n_tested,
	 ':n_ok'     => $n_ok,
	 ':id'       => $id
       );
  $q = &dbexec($self->{DBH},$sql,%p);
}

sub setRequestState
{
# Change the state of a request in the database
  my ($self, $request, $state) = @_;
  my ($sql,%p,$q);
  my (@nodes);
  return unless defined $request->{ID};

  $self->Logmsg("Request=$request->{ID}, state=$state");

  $sql = qq{
	update t_status_block_verify sbv 
	set time_reported = :time,
	status = 
	 (select id from t_dvs_status where name like :state )
	where id = :id
       };
  %p = ( ':id'    => $request->{ID},
         ':state' => $state,
         ':time'  => time()
       );
  while ( 1 )
  {
    eval { $q = &dbexec($self->{DBH},$sql,%p); };
    last unless $@;
    die $@ if ( $@ !~ m%ORA-25408% );
    sleep 63; # wait a bit and retry...
  }
}

sub isInvalid
{
  my $self = shift;
  my $errors = $self->SUPER::isInvalid
		(
		  REQUIRED => [ qw / NODES DBCONFIG / ],
		);
  return $errors;
}

1;
