package PHEDEX::BlockConsistency::Agent;

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::BlockConsistency::SQL', 'PHEDEX::Core::Logging';

use File::Path;
use File::Basename;
use Cwd;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Formats;
use PHEDEX::Core::Catalogue;
use PHEDEX::Core::DB;
use PHEDEX::BlockConsistency::Core;
use PHEDEX::Core::Loader;
use POE;
use POE::Queue::Array;

our %params =
	(
	  WAITTIME	=> 300 + rand(15),	# Agent activity cycle
          PROTOCOL      => undef,               # File access protocol
	  PRELOAD	=> undef,		# Library to preload for dCache?
	  ME => 'BlockDownloadVerify',		# Name for the record...
	  NAMESPACE	=> 'posix',
	  max_priority	=> 0,			# max of active requests
	  QUEUE_LENGTH	=> 100,			# length of queue per cycle
          MAX_QUEUE_LENGTH => 900,              # upper limit if the ajustable queue length, do not change it.
          FIX_QUEUE_LENGTH => 'y',              # turn on/off queue length 
          DBS_URL       => undef,               # DBS URL to contact, if not set URL from TMDB will be used
          CLEAN_STARTUP => 'y',                 # Clean request leave in Active State
          AGENT_CACHE_MAXFILES => 10000,        # Maximum number of files allow in cache
          AGENT_CACHE_AGE => 60 * 30,           # Maximum age of files in cache
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new(%params,@_);

  $self->{bcc}          = PHEDEX::BlockConsistency::Core->new();
  $self->{QUEUE}        = POE::Queue::Array->new();
  $self->{RESULT_QUEUE} = POE::Queue::Array->new();

  $self->{AGENT_CACHE_QUEUE}     = POE::Queue::Array->new();      # Holds the ordered-queue of deletions from the cache
  $self->{AGENT_CACHE_LOCAL}     = {size => 0, entries => {}};    # Holds list of files entered by req-id (block)
  $self->{AGENT_CACHE_NAMESPACE} = {};                            # The actual cache managed by the Namespace

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
  my $scriptdir = $self->{ENVIRONMENT}->getExpandedParameter('PHEDEX_SCRIPTS');
  my $dbs = $scriptdir . '/Toolkit/DBS/DBSgetLFNsFromBlock';
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
  my ($ns,$loader,$cmd);
  
  $self->Dbgmsg("doNSCheck: starting") if ( $self->{DEBUG} );

  $self->{bcc}->Checks($request->{TEST}) or
    die "Test $request->{TEST} not known to ",ref($self),"!\n";

  # Load the catalogue only on the first execution; afterwards just update its DB connection
  # Note - if the agent is running for multiple nodes, it will use only the catalogue of the first one
  if ( $self->{CATALOGUE} ) {
      $self->{CATALOGUE}->{DBH} = $self->{DBH};
  }
  else {
      $self->{CATALOGUE} = PHEDEX::Core::Catalogue->new( $self->{DBH} , $self->{NODES}[0] );
  }
  
  if ( $self->{NAMESPACE} )
  {
    $loader = PHEDEX::Core::Loader->new( NAMESPACE => 'PHEDEX::Namespace' );
    $ns = $loader->Load($self->{NAMESPACE})->new( AGENT => $self,
						  CATALOGUE => $self->{CATALOGUE},
						  PROTOCOL => $self->{PROTOCOL} );
    if ( $request->{TEST} eq 'size' )      { $cmd = 'size'; }
    if ( $request->{TEST} eq 'cksum' )     { $cmd = 'checksum_value'; }
    if ( $request->{TEST} eq 'migration' ) { $cmd = 'is_migrated'; }
  }
  else
  {
    die "No Namespace provided\n"; 
  }
  
  $self->Dbgmsg("doNSCheck: Request ",$request->{ID}) if ( $self->{DEBUG} );
  $n_files = $request->{N_FILES};
  my $t = time;
  my $cs_t = $t;
  my $t0 = Time::HiRes::time();
  my ($t1,$dt1,$dt0);
  $dt1 = 0.;
  $self->Dbgmsg("Start the checking of $n_files local files at $t0") if ( $self->{DEBUG} );
  
  my ($were_tested,$were_ok,$were_fail,$were_n);
  $were_tested = $were_ok = $were_fail = 0;
  $were_n = $n_files;

  my $agent_reqid = 'req_id_' . $request->{ID};  # We will use this as blockname?

  foreach my $r ( @{$request->{LFNs}} )
  {
    no strict 'refs';
    my $lfn = $r->{LOGICAL_NAME};
 
    $were_tested++;

    push(@{$self->{AGENT_CACHE_LOCAL}->{entries}{$agent_reqid}}, $lfn);   # store the file that will go into cache
    $self->{AGENT_CACHE_LOCAL}->{size} ++;                                # increase the local counter


    if ( $request->{TEST} eq 'size' )
    {
      $t1 = Time::HiRes::time();
      my $size = $ns->$cmd($lfn);
      $dt1 += Time::HiRes::time() - $t1;
      if ( defined($size) && $size == $r->{FILESIZE} ) { $r->{STATUS} = 'OK'; $were_ok++;}
      else { $r->{STATUS} = 'Fail'; $were_fail++;}
    }
    elsif ( $request->{TEST} eq 'migration' ||
	    $request->{TEST} eq 'is_migrated' )
    {
      my $mode = $ns->$cmd($lfn);
      if ( defined($mode) && $mode ) { $r->{STATUS} = 'OK'; $were_ok++;}
      else { $r->{STATUS} = 'Fail'; $were_fail++;}
    }
    elsif ( $request->{TEST} eq 'cksum' ) 
    {
      my $chksum_value;
      my $checksum_map;
      eval {$checksum_map=PHEDEX::Core::Formats::parseChecksums($r->{CHECKSUM});};
      if ($@) 
      { 
	  $self->Alert("File $lfn: ",$@);
      }
      else
      {
	  $chksum_value=$checksum_map->{adler32};
      }
      
      if (defined $chksum_value)
      { 
	  $chksum_value=hex($chksum_value); 
      }
      else
      { 
	  $r->{STATUS} = 'Indeterminate'; 
	  $self->Dbgmsg("$lfn : no adler32 checksum in TMDB") if ( $self->{DEBUG} );
	  next; 
      }
      $t1 = Time::HiRes::time();
      my $adler = $ns->$cmd($lfn);
      if ( defined($adler) ) { $adler = hex($adler) }
      else                   { $adler = 'undefined'; }
      $dt1 += Time::HiRes::time() - $t1;
      if ( defined($adler) &&  $adler eq $chksum_value ) { $r->{STATUS} = 'OK'; $were_ok++;}
      else { $r->{STATUS} = 'Fail'; $were_fail++;
             $self->Dbgmsg("$lfn : $chksum_value  <>  $adler") if ( $self->{DEBUG} );
           }
    }
    $r->{TIME_REPORTED} = time();
    last unless --$n_files;
    if ( time - $t > 60 )
    {
      $self->Dbgmsg("$n_files files remaining") if ( $self->{DEBUG} );
      $t = time;
      if ( $t - $cs_t > 30*60 ) 
      {
        $self->Dbgmsg("Agent busy performing a long test, refreshing connection to DB") if ( $self->{DEBUG} ); 
        $self->updateAgentStatus();       # This should update the status of the agent in the DB
        $self->Notify('ping');            # This should update the timer in Watchdog
        $cs_t = $t;
      }
    }
  }

  $self->{AGENT_CACHE_QUEUE}->enqueue(time, $agent_reqid);                 # Put the blockname in the ordered queue

  $request->{N_TESTED} = $were_tested;
  $request->{N_OK} = $were_ok;
  if ( $were_n > 0 && $were_ok == $were_n ) { $request->{STATUS} = 'OK';}
  elsif ( $were_n > 0 && $were_fail > 0 ) { $request->{STATUS} = 'Fail';}
  else { $request->{STATUS} = 'Indeterminate';}
  $request->{TIME_REPORTED} = time(); 

  $dt0 = Time::HiRes::time() - $t0;
  $self->Dbgmsg("$were_tested files tested in $dt0 sec (ls/cksum = $dt1 sec)") if ( $self->{DEBUG} );

  $self->{RESULT_QUEUE}->enqueue($request->{PRIORITY},$request);

  my $status = ( $were_n == $were_ok ) ? 1 : 0;
  return $status;
}

# Try to perform some update of the DB before stop flag
sub stop
{
  my $self = shift;
  
  $self->Logmsg("stop: Force update of database");
  my $session = $poe_kernel->get_active_session;
  $poe_kernel->call($session,'upload_result');
}

sub _poe_init
{
  my ($self,$kernel) = @_[ OBJECT, KERNEL ];
  $kernel->state('do_tests',$self);
  $kernel->state('get_work',$self);
  $kernel->state('requeue_later',$self);
  $kernel->state('upload_result',$self);
  $kernel->state('delete_from_cache',$self);
  $kernel->yield('get_work');
  $kernel->delay_set('upload_result',$self->{WAITTIME} / 2);
}

sub delete_from_cache
{
  my ($self, $kernel) = @_[ OBJECT, KERNEL ];
 
# If the first entry is not yet stale and the cache is small enough, do not delete the entry.
# Otherwise, delete the entry...
# ...then check if the cache is too large, and delete another entry straight away if so
 my ($priority, $queue_id, $blockName) = $self->{AGENT_CACHE_QUEUE}->dequeue_next();

 return unless defined $priority;                                 # This means there was nothing left in the cache
 return unless $self->{AGENT_CACHE_LOCAL}->{entries}{$blockName}; # In case the cache was purged by other means...?

 my $age = time - $priority;
 if ( $age < $self->{AGENT_CACHE_AGE} && $self->{AGENT_CACHE_LOCAL}->{size} <= $self->{AGENT_CACHE_MAXFILES} ) {
  $self->Dbgmsg("delete_from_cache: Dequeued $blockName, but is not yet stale. Re-inserting in queue") if $self->{DEBUG};
  $self->{AGENT_CACHE_QUEUE}->enqueue($priority, $blockName);
  return;
 }

 $kernel->yield('delete_from_cache');   # come back again, this will stop when all files in cache are within the cache limits

 my $nfiles_in_block = scalar @{$self->{AGENT_CACHE_LOCAL}->{entries}{$blockName}};

 $self->Dbgmsg("delete_from_cache: Flush block $blockName from the cache, remove $nfiles_in_block  files") if $self->{DEBUG};
 $self->{AGENT_CACHE_LOCAL}->{size} -= $nfiles_in_block;

 foreach my $lfn_in_cache ( @{$self->{AGENT_CACHE_LOCAL}->{entries}{$blockName}} )
 {
   if (exists ($self->{AGENT_CACHE_NAMESPACE}->{$lfn_in_cache}) ) { delete $self->{AGENT_CACHE_NAMESPACE}->{$lfn_in_cache}; }
 }

 delete $self->{AGENT_CACHE_LOCAL}->{entries}{$blockName};

 my $nfiles_in_cache = scalar keys %{$self->{AGENT_CACHE_NAMESPACE}};
 $self->Dbgmsg("delete_from_cache: nfiles in cache $nfiles_in_cache  and size of local cache $self->{AGENT_CACHE_LOCAL}->{size}") if $self->{DEBUG};

 $self->Dbgmsg("delete_from_cache: Local cache has too many entries $self->{AGENT_CACHE_LOCAL}->{size} > $self->{AGENT_CACHE_MAXFILES} ") if ( $self->{AGENT_CACHE_LOCAL}->{size} > $self->{AGENT_CACHE_MAXFILES} );

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
    $self->Logmsg("upload_result: Results in queue. Updating database ...");
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

sub is_test_possible
{
  my ($self, $cmd) = @_;
  my ($ns,$loader);

  if ( $self->{NAMESPACE} )
  {
    $loader = PHEDEX::Core::Loader->new( NAMESPACE => 'PHEDEX::Namespace' );
    $ns = $loader->Load($self->{NAMESPACE})->new( AGENT => $self );
    if ( $cmd eq 'migration' ) { $cmd = 'is_migrated'; }
    if ( $cmd eq 'cksum' ) { $cmd = 'checksum_value'; }
    if ( exists($ns->{MAP}{$cmd}) ) { return 1; }
  }
  return 0;
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
# put a hard limit of MAX_QUEUE_LENGTH 
     my $dt0   = time() - $self->{TIME_QUEUE_FETCH};
     my $scale= ( $dt0 > 30 ) ? $self->{WAITTIME}/$dt0 : 0;
     if ( $self->{FIX_QUEUE_LENGTH} eq 'y'  && ($self->{WAITTIME} - $dt0) > 30 && $scale && $self->{LAST_QUEUE} == $self->{QUEUE_LENGTH} ) {
        my $new_queue_length = int($self->{QUEUE_LENGTH} * $scale);
        $self->{QUEUE_LENGTH} = ($new_queue_length <= $self->{MAX_QUEUE_LENGTH}) ? $new_queue_length : $self->{MAX_QUEUE_LENGTH}; 
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

    if ( $self->is_test_possible($request->{TEST}) )
    {
      $self->setRequestState($request,'Active');
      $self->{DBH}->commit();
      my $result = $self->doNSCheck ($request);
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
		select b.id, b.block, b.n_files, b.time_expire, b.priority,
		t.name test, b.use_srm
		from t_dvs_block b
		join t_dps_block bk on bk.id = b.block
		join t_dvs_test t on b.test = t.id
		join t_status_block_verify v on b.id = v.id
		where ${$mfilter}
		and v.status in (0,3)
		${$ofilter}
		order by b.priority asc, b.time_expire asc, bk.dataset desc
       };
  %p = (  %{$mfilter_args}, %{$ofilter_args} );
  $q = &dbexec($self->{DBH},$sql,%p);

  $sql = qq{ select pf.logical_name, pf.checksum, pf.filesize, vf.fileid,
		nvl(vfr.time_reported,0) time_reported, nvl(vfr.status,0) status
		from t_dps_file pf join t_dvs_file vf on vf.fileid = pf.id
		left join t_dvs_file_result vfr on vfr.fileid = vf.fileid
		where vf.request = :request
		order by vf.fileid asc, nvl(vfr.time_reported,0) desc
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

# Set to Queued state requests leave on Active state from previous runs  
sub FixActiveRequest
{
  my ($self, $mfilter, $mfilter_args, $ofilter, $ofilter_args) = @_;
  my ($sql,%p,$q,$i);

  $self->Dbgmsg("FixActiveRequest: starting") if ( $self->{DEBUG} );

  $sql = qq{
                select b.id, b.block, b.n_files, b.time_expire, b.priority,
                t.name test, b.use_srm
                from t_dvs_block b join t_dvs_test t on b.test = t.id
                join t_status_block_verify v on b.id = v.id
                where ${$mfilter}
                and v.status = 4
                ${$ofilter}
                order by b.priority asc, b.time_expire asc
       };

  %p = (  %{$mfilter_args}, %{$ofilter_args} );
  $q = &dbexec($self->{DBH},$sql,%p);
 
  $i = 0; 
  while ( my $h = $q->fetchrow_hashref() ) {
                                             $self->setRequestState($h,'Queued');
                                             $i++; 
                                           }

  $self->Logmsg("Found $i requests left in Active status during last Agent stop, they were set to Queued state") if ( $i );
  return;
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
    if ( $self->{CLEAN_STARTUP} eq 'y' ) { 
       $self -> FixActiveRequest(\$mfilter, \%mfilter_args, \$ofilter, \%ofilter_args);
       $self->{CLEAN_STARTUP} = 'n';
    }

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

  $kernel->yield('delete_from_cache');  # loop for old stuff in cache, no matter if work has to be done or not

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
