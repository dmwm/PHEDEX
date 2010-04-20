package PHEDEX::BlockConsistency::Agent;

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
	  max_priority	=> 0,			# max of active requests
	  QUEUE_LENGTH	=> 100,			# length of queue per cycle
          DBS_URL       => undef,               # DBS URL to contact, if not set URL from TMDB will be used
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new(%params,@_);
  $self->{bcc} = PHEDEX::BlockConsistency::Core->new();
  $self->{QUEUE} = POE::Queue::Array->new();
  $self->{RESULT_QUEUE} = POE::Queue::Array->new();
  $self->{NAMESPACE} =~ s%['"]%%g if $self->{NAMESPACE};

# Don't set this below 5 minutes, since it is the time interval you will be accessing the DB 
  if ( $self->{WAITTIME} < 300 ) { $self->{WAITTIME} = 300 + rand(15); }
  $self->{TIME_QUEUE_FETCH} = 0;
  $self->{LAST_QUEUE} = 0;  

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

  $self->Dbgmsg("doDBSCheck: starting") if ( $self->{DEBUG} );
  $self->{bcc}->Checks($request->{TEST}) or
    die "Test $request->{TEST} not known to ",ref($self),"!\n";

  $self->Dbgmsg("doDBSCheck: Request ",$request->{ID}) if ( $self->{DEBUG} );
  $n_files = $request->{N_FILES};

  my $t0 = Time::HiRes::time(); 

# fork the dbs call and harvest the results
  my $d = dirname($0);
  if ( $d !~ m%^/% ) { $d = cwd() . '/' . $d; }
  my $dbs = $d . '/DBSgetLFNsFromBlock';
  my $dbsurl;
  if ( $self->{DBS_URL} )
  {
    $dbsurl = $self->{DBS_URL};
  }
  else
  {
    my $r = $self->getDBSFromBlockIDs($request->{BLOCK});
    $dbsurl = $r->[0] or die "Cannot get DBS url?\n";
  }
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

  $n_tested = $n_ok = 0;
  $n_files = $request->{N_FILES};
  foreach my $r ( @{$request->{LFNs}} )
  {
    $n_tested++;
    if ( delete $dbs{$r->{LOGICAL_NAME}} ) { $r->{STATUS} = 'OK';  $n_ok++}
    else                                   { $r->{STATUS} = 'Fail'; }
    $r->{TIME_REPORTED} = time();
  }
  $n_files = $n_tested + scalar keys %dbs;
  if ( scalar keys %dbs ) {  $self->Logmsg("DBS has more than TMBD, test failed!"); }
#      die "Hmm, how to handle this...? DBS has more than TMDB!\n";
#      $self->setRequestState($request,'Suspended'); }

  $request->{N_TESTED} = $n_tested;
  $request->{N_OK} = $n_ok;
  if ( $n_files == 0 )        { $request->{STATUS} = 'Indeterminate';}
  elsif ( $n_ok == $n_files ) { $request->{STATUS} = 'OK';}
  else                        { $request->{STATUS} = 'Fail';}
  $request->{TIME_REPORTED} = time();

  my $dt0 = Time::HiRes::time() - $t0;
  $self->Dbgmsg("$n_tested files tested ($n_ok,$n_files) in $dt0 sec") if ( $self->{DEBUG} );

  $self->{RESULT_QUEUE}->enqueue($request->{PRIORITY},$request);

  my $status = ( $n_files == $n_ok ) ? 1 : 0;
  return $status;
}

sub doNSCheck
{
  my ($self, $request) = @_;
  my $n_files = 0;
  my ($ns,$loader,$cmd,$mapping);
  my @nodes = ();

  $self->Dbgmsg("doNSCheck: starting") if ( $self->{DEBUG} );

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

  my $tfcprotocol = 'direct';
  if ( $self->{NAMESPACE} )
  {
    $loader = PHEDEX::Core::Loader->new( NAMESPACE => 'PHEDEX::Namespace' );
    $ns = $loader->Load($self->{NAMESPACE})->new( AGENT => $self );
    if ( $request->{TEST} eq 'size' )      { $cmd = 'size'; }
    if ( $request->{TEST} eq 'migration' ) { $cmd = 'is_migrated'; }
    $tfcprotocol = $ns->Protocol();
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

  if ( $self->{USE_SRM} eq 'y' or $request->{USE_SRM} eq 'y' )
  { $tfcprotocol = 'srm'; }

  $self->Dbgmsg("doNSCheck: Request ",$request->{ID}) if ( $self->{DEBUG} );
  $n_files = $request->{N_FILES};
  my $t = time;
  my $t0 = Time::HiRes::time();
  my ($t1,$dt1,$dt0);
  $dt1 = 0.;
  $self->Dbgmsg("Start the checking of $n_files local files at $t0") if ( $self->{DEBUG} );
  
  my ($were_tested,$were_ok,$were_n);
  $were_tested = $were_ok = 0;
  $were_n = $n_files;

  foreach my $r ( @{$request->{LFNs}} )
  {
    no strict 'refs';
    my $pfn;
    my $node = $self->{NODES}[0];
    my $lfn = $r->{LOGICAL_NAME};
    $pfn = &applyStorageRules($mapping,$tfcprotocol,$node,'pre',$lfn,'n');
    $were_tested++;
    if ( $request->{TEST} eq 'size' )
    {
      $t1 = Time::HiRes::time();
      my $size = $ns->$cmd($pfn);
      $dt1 += Time::HiRes::time() - $t1;
      if ( defined($size) && $size == $r->{FILESIZE} ) { $r->{STATUS} = 'OK'; $were_ok++;}
      else { $r->{STATUS} = 'Fail'; }
    }
    elsif ( $request->{TEST} eq 'migration' ||
	    $request->{TEST} eq 'is_migrated' )
    {
      my $mode = $ns->$cmd($pfn);
      if ( defined($mode) && $mode ) { $r->{STATUS} = 'OK'; $were_ok++;}
      else { $r->{STATUS} = 'Fail'; }
    }
    $r->{TIME_REPORTED} = time();
    last unless --$n_files;
    if ( time - $t > 60 )
    {
      $self->Dbgmsg("$n_files files remaining") if ( $self->{DEBUG} );
      $t = time;
    }
  }

  $request->{N_TESTED} = $were_tested;
  $request->{N_OK} = $were_ok;
  if ( $were_n == 0 )           { $request->{STATUS} = 'Indeterminate';}    
  elsif ( $were_ok == $were_n ) { $request->{STATUS} = 'OK';}    
  else                          { $request->{STATUS} = 'Fail';}
  $request->{TIME_REPORTED} = time(); 

  $dt0 = Time::HiRes::time() - $t0;
  $self->Dbgmsg("$were_tested files tested in $dt0 sec (ls = $dt1 sec)") if ( $self->{DEBUG} );

  $self->{RESULT_QUEUE}->enqueue($request->{PRIORITY},$request);

  my $status = ( $were_n == $were_ok ) ? 1 : 0;
  return $status;
}

sub _poe_init
{
  my ($self,$kernel) = @_[ OBJECT, KERNEL ];
  $kernel->state('do_tests',$self);
  $kernel->state('get_work',$self);
  $kernel->state('requeue_later',$self);
  $kernel->state('upload_result',$self);
  $kernel->yield('get_work');
  $kernel->delay_set('upload_result',$self->{WAITTIME} / 2);
}

sub upload_result
{
  my ($self, $kernel) = @_[ OBJECT, KERNEL ];
  my ($request,$id,$priority);
  my $rows = 0;
  my $tfiles = 0;
  my (%FileState,%RequestFileCount,%RequestState);

# Make sure to come back again at a later time
  $kernel->delay_set('upload_result',$self->{WAITTIME});

  $self->{pmon}->State('upload_result','start');
  my $current_queue_size = $self->{RESULT_QUEUE}->get_item_count();
  if ( ! $current_queue_size ) { $self->Dbgmsg("upload_result: No results in queue") if $self->{DEBUG}; } 
  else {
# If we have already made some test, then update the database, but just for the current results in queue
    $self->Dbgmsg("upload_result: Results in queue. Updating database ...") if $self->{DEBUG};
    my $t0 = Time::HiRes::time();
    my $tmp_queue = POE::Queue::Array->new();  # to save results in case of failure

    my $qFS  = &dbprep($self->{DBH}, qq{insert into t_dvs_file_result fr (id,request,fileid,time_reported,status)
	values (seq_dvs_file_result.nextval,?,?,?, (select id from t_dvs_status where name like ?))});
    my $qRFC = &dbprep($self->{DBH}, qq{update t_status_block_verify set n_tested = ?, n_ok = ? where id = ?});
    my $qRS  = &dbprep($self->{DBH}, qq{update t_status_block_verify sbv set time_reported = ?, 
        status = (select id from t_dvs_status where name like ?) where id = ?});

    eval {
      while ( $current_queue_size > 0 ) {
       ($priority,$id,$request) = $self->{RESULT_QUEUE}->dequeue_next();
       $tmp_queue -> enqueue($priority,$request);
       $self->Dbgmsg("upload_result: Preparing request $request->{ID}") if $self->{DEBUG};
 
       foreach my $r ( @{$request->{LFNs}} ) {
          next unless $r->{STATUS};
          push(@{$FileState{1}}, $request->{ID});
          push(@{$FileState{2}}, $r->{FILEID});
          push(@{$FileState{3}}, $r->{TIME_REPORTED});
          push(@{$FileState{4}}, $r->{STATUS});
          $rows++; $tfiles++;
       }
       push(@{$RequestFileCount{1}}, $request->{N_TESTED});
       push(@{$RequestFileCount{2}}, $request->{N_OK});
       push(@{$RequestFileCount{3}}, $request->{ID});
       $rows++;
       push(@{$RequestState{1}}, $request->{TIME_REPORTED});
       push(@{$RequestState{2}}, $request->{STATUS});
       push(@{$RequestState{3}}, $request->{ID});
       $rows++;
       if ( $rows > 1000 ) {
	 if ($tfiles > 0 ) { &dbbindexec($qFS,%FileState); }
	 &dbbindexec($qRFC,%RequestFileCount);
	 &dbbindexec($qRS, %RequestState);
         $self->{DBH}->commit(); 
#        Make sure, we clean up everything
         my $nup =  scalar ($tmp_queue->remove_items(sub{1}));
         $self->Dbgmsg("upload_result: $nup requests uploaded (rows = $rows, $tfiles)") if $self->{DEBUG};
         $rows = 0; $tfiles = 0;
         %FileState = ();
         %RequestFileCount = ();
         %RequestState = ();     
       }
       $current_queue_size--;
      }
      if ( $rows > 0 ) {
	 if ($tfiles > 0) { &dbbindexec($qFS,%FileState); }
	 &dbbindexec($qRFC,%RequestFileCount);
	 &dbbindexec($qRS, %RequestState);

         $self->{DBH}->commit();
         my $nup =  scalar ($tmp_queue->remove_items(sub{1}));
         $self->Dbgmsg("upload_result: remaining $nup request uploaded (rows = $rows, $tfiles)") if $self->{DEBUG};
      }
    }; 
    if ( $self->rollbackOnError() ) {
# put back everything as it was 
      while ( $tmp_queue -> get_item_count() > 0) { 
        ($priority,$id,$request) = $tmp_queue->dequeue_next();
        $self->{RESULT_QUEUE} -> enqueue($priority,$request);
      } 
    }
    my $dt0 = Time::HiRes::time() - $t0;
    $self->Dbgmsg("upload_result: Database updated in $dt0 sec") if $self->{DEBUG};    
  }

  $self->{pmon}->State('upload_result','stop');
}

sub do_tests
{
  my ($self, $kernel) = @_[ OBJECT, KERNEL ];
  my ($request,$r,$id,$priority);

  ($priority,$id,$request) = $self->{QUEUE}->dequeue_next();

  unless ($request) {
# I drained the queue, make a larger queue: First make sure that something has been made, i.e. we at least
# have spend few seconds, then see if there is room for improvement, i.e. at least there are few idle seconds
# and finally check that we perform a full cycle. It so, make a bigger queue proportional to the time left
# put a hard limit of 900 
     my $dt0   = time() - $self->{TIME_QUEUE_FETCH};
     my $scale= ( $dt0 > 30 ) ? $self->{WAITTIME}/$dt0 : 0;
     if ( ($self->{WAITTIME} - $dt0) > 30 && $scale && $self->{LAST_QUEUE} == $self->{QUEUE_LENGTH} ) {
        my $new_queue_length = int($self->{QUEUE_LENGTH} * $scale);
        $self->{QUEUE_LENGTH} = ($new_queue_length <= 900) ? $new_queue_length : 900; 
        $self->Dbgmsg("do_tests: Queue too small, increasing QUEUE_LENGTH to $self->{QUEUE_LENGTH}") if ($self->{DEBUG});
     } 
     return;
  }

# I got a request, so make sure I come back again soon for another one
  $kernel->yield('do_tests');

  $self->{pmon}->State('do_tests','start');
# Sanity checking
  &timeStart($$self{STARTTIME});

  eval {
    $self->connectAgent();
    $self->{bcc}->DBH( $self->{DBH} );

    if ( $request->{TIME_EXPIRE} <= time() )
    {
      $self->setRequestState($request,'Expired');
      $self->Dbgmsg("do_tests: return after Expiring $request->{ID}");
      return;
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
      $self->Logmsg("do_tests: return after Rejecting $request->{ID}");
    }
    $self->{DBH}->commit();
  };
  if ( $self->rollbackOnError() ) {
#   put everything back the way it was...
#   ...and requeue the request in memory. But, schedule it for later, and lower
#   the priority. That way, if it is a hard error, it should not block things
#   totally, and if it is a soft error, it should go away eventually.
#   (N.B. 'lower' priority means numerically higher!)
    $request->{PRIORITY} = ++$self->{max_priority};
    $kernel->delay_set('requeue_later',60,$request);
  } 

  $self->{pmon}->State('do_tests','stop');
}

sub requeue_later
{
  my ($self, $kernel, $request) = @_[ OBJECT, KERNEL, ARG0 ];
  eval {
  	if ( ++$request->{attempt} > 10 )
  	{
	  $self->Alert('giving up on request ID=',$request->{ID},', too many hard errors');
	  $self->setRequestState($request,'Error');
	  $self->{DBH}->commit();
	  return;
  	}
# Before re-queueing, check if any other requests are active. If not, I need
# to kick this into action when I re-queue. Otherwise, it waits for the next
# time get_work finds something to do!
	$self->Logmsg('Requeue request ID=',$request->{ID},' after ',$request->{attempt},' attempts');
	if ( ! $self->{QUEUE}->get_item_count() ) { $kernel->yield('do_tests'); } 
	$self->{QUEUE}->enqueue($request->{PRIORITY},$request);
       };
  $self->rollbackOnError();
};

# Get a list of pending requests
sub requestQueue
{
  my ($self, $limit, $mfilter, $mfilter_args, $ofilter, $ofilter_args) = @_;
  my (@requests,$sql,%p,$q,$q1,$n,$i);

  $self->Dbgmsg("requestQueue: starting") if ( $self->{DEBUG} );
  my $now = &mytimeofday();

# Find all the files that we are expected to work on
  $n = 0;

  $sql = qq{
		select b.id, block, n_files, time_expire, priority,
		name test, use_srm
		from t_dvs_block b join t_dvs_test t on b.test = t.id
		join t_status_block_verify v on b.id = v.id
		where ${$mfilter}
		and status in (0,3)
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
#   max_priority is guaranteed to be correct at the end of this loop by the
#  'order by priority asc' in the sql. Use it to adjust priority in case of
#   unknown problems
    $self->{max_priority} = $h->{PRIORITY};
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

sub get_work
{
# get work from the database. This function reschedules itself for the future, to fetch
# newer work. If there is unfinished work, this function will call itself again soon,
# and then exit without doing anything. Otherwise, it attempts to get a large chunk of
# work, and re-schedules itself somewhat later.
  my ($self, $kernel) = @_[ OBJECT, KERNEL ];
  my @nodes = ();

  if ( $self->{QUEUE}->get_item_count() )
  {
#   There is work queued, so the agent is 'busy'. Check again soon
    $self->Dbgmsg("get_work: The agent is busy") if ( $self->{DEBUG} );
    $kernel->delay_set('get_work',10);
    return;
  }
# The agent is idle. Check somewhat less frequently
  $self->Dbgmsg("get_work: The agent is idle") if ( $self->{DEBUG} );
  $kernel->delay_set('get_work',$self->{WAITTIME});

  $self->{pmon}->State('get_work','start');
  eval
  {
    $self->connectAgent();
    @nodes = $self->expandNodes();
    @nodes or die "No node found? Typo perhaps?\n";
    my ($mfilter, %mfilter_args) =    $self->myNodeFilter ("b.node");
    my ($ofilter, %ofilter_args) = $self->otherNodeFilter ("b.node");

#   Get a list of requests to process
    foreach my $request ($self->requestQueue($self->{QUEUE_LENGTH},
					\$mfilter, \%mfilter_args,
					\$ofilter, \%ofilter_args))
    {
      $self->{QUEUE}->enqueue($request->{PRIORITY},$request);
      $self->setRequestState($request,'Queued');
    }
    $self->{DBH}->commit();
  }; 
  $self->rollbackOnError();

# If we found new tests to perform, but there were none already in the queue, kick off
# the do_tests loop
  $self->{LAST_QUEUE} = $self->{QUEUE}->get_item_count();
  $self->{TIME_QUEUE_FETCH} = time();

  if ( $self->{QUEUE}->get_item_count() ) { $kernel->yield('do_tests'); }
  else                                    { $self->disconnectAgent(); }   # Disconnect from the database

  $self->{pmon}->State('get_work','stop');
  return;
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
