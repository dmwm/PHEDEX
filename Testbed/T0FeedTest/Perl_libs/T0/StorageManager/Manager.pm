use strict;
package T0::StorageManager::Manager;
use Sys::Hostname;
use POE;
use POE::Filter::Reference;
use POE::Component::Server::TCP;
use POE::Queue::Array;
use T0::Util;
use T0::FileWatcher;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);

use Carp;
$VERSION = 1.00;
@ISA = qw/ Exporter /;
$StorageManager::Name = 'SM::Manager';

our (@queue,%q);

our $hdr = __PACKAGE__ . ':: ';
sub Croak   { croak $hdr,@_; }
sub Carp    { carp  $hdr,@_; }
sub Verbose { T0::Util::Verbose( (shift)->{Verbose}, @_ ); }
sub Debug   { T0::Util::Debug(   (shift)->{Debug},   @_ ); }
sub Quiet   { T0::Util::Quiet(   (shift)->{Quiet},   @_ ); }

sub _init
{
  my $self = shift;

  $self->{Name} = $StorageManager::Name;
  my %h = @_;
  map { $self->{$_} = $h{$_}; } keys %h;
  $self->ReadConfig();
  check_host( $self->{Host} ); 

  POE::Component::Server::TCP->new
  ( Port                => $self->{Port},
    Alias               => $self->{Name},
    ClientFilter        => "POE::Filter::Reference",
    ClientInput         => \&_client_input,
    ClientDisconnected  => \&_client_disconnected,
    ClientError         => \&_client_error,
    Started             => \&_started,
    ObjectStates	=> [
	$self => [
		        started	=> 'started',
		    build_queue	=> 'build_queue',
		   client_input	=> 'client_input',
		   client_error	=> 'client_error',
	    client_disconnected	=> 'client_disconnected',
		       set_rate	=> 'set_rate',
      	      handle_unfinished => 'handle_unfinished',
		      send_work => 'send_work',
		     send_setup => 'send_setup',
		     send_start => 'send_start',
		   file_changed => 'file_changed',
		      broadcast	=> 'broadcast',
		 ],
	],
    Args => [ $self ],
  );

  return $self;
}

sub new
{
  my $proto  = shift;
  my $class  = ref($proto) || $proto;
  my $parent = ref($proto) && $proto;
  my $self = {  };
  bless($self, $class);
  $self->_init(@_);
}

sub Options
{ 
  my $self = shift;
  my %h = @_;
  map { $self->{$_} = $h{$_}; } keys %h;
}

our @attrs = ( qw/ Name Host Port ConfigRefresh Config / );
our %ok_field;
for my $attr ( @attrs ) { $ok_field{$attr}++; }

sub AUTOLOAD {
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  Croak "AUTOLOAD: Invalid attribute method: ->$attr()" unless $ok_field{$attr};
  if ( @_ ) { Croak "Setting attributes not yet supported!\n"; }
# $self->{$attr} = shift if @_;
  return $self->{$attr};
}

sub AddWorker
{
  my $self = shift;
  my $client = shift or Croak "Expected a client name...\n";
  $self->{clients}->{$client} = POE::Queue::Array->new();
}

sub RemoveWorker
{
  my $self = shift;
  my $client = shift or Croak "Expected a client name...\n";
  delete $self->{clients}->{$client};
}

sub Queue
{
  my $self = shift;
  my $client = shift;
  if ( defined($client) ) { return $self->{clients}->{$client}; }
  return undef;
}

sub Workers
{
  my $self = shift;
  my $client = shift;
  if ( defined($client) ) { return $self->{clients}->{$client}; }
  return keys %{$self->{clients}};
}

sub GatherStatistics
{
  my $self = shift;
  my $i = shift or return;
  push @{$self->{stats}}, $i;
}

sub Log
{
  my $self = shift;
  my $logger = $self->{Logger};
  defined $logger && $logger->Send(@_);
}

sub set_rate
{
  my ( $self, $kernel, $heap, $session ) = @_[  OBJECT, KERNEL, HEAP, SESSION ];
  my ($i,$j,$r,$s,$sum);
  $self->{StatisticsInterval} = 60 unless defined($self->{StatisticsInterval});
  $self->{LastStatsCount}      = 0 unless defined($self->{LastStatsCount});

  $s = $self->{StatisticsInterval};

  $kernel->delay( 'set_rate', $self->{StatisticsInterval} );
  $r = $self->{TargetRate};
  Print "Checking rate wrt $r MB/s\n" if defined($r);
  
  $sum = $i = 0;
  while ( $_ = shift @{$self->{stats}} )
  {
    $sum+= $_;
    $i++;
  }

# Sanity-checks. Return unless I have something to analyse, and return unless
# I had something in the last cycle too (so I am sure this is a full cycle)
  if ( !$sum )
  {
    Print "No data to measure rate with...\n";
    return;
  }
  $j = $self->{LastStatsCount};
  $self->{LastStatsCount} = $i;
  if ( ! $j )
  {
    Print "Not gathering statistics for long enough...\n";
    return;
  }

  $sum = int($sum*100/1024/1024)/100;
  $self->Debug("$sum MB in $s seconds, $i readings\n");
  my ($se,$re,$smax);
  $re = $sum/$s;

  my ($x,$stable,$repcnt);
  if ( defined($r) )
  {
    $x = ($r>$re) ? $r/$re : $re/$r;
    $x = int(10000*($x-1))/100;
  }
  else { $x = $r = 0; }
  $repcnt = int(100*$re)/100;
  $stable = 0;
  if ( defined($self->{RateTolerance}) && $x < $self->{RateTolerance} )
  { $stable = 1; }
  Print "Rate: $repcnt ($x% off wrt $r, $i readings)",($stable ? " STABLE":''),"\n";
  my %h = (	MonaLisa => 1,
		Cluster	 => $T0::System{Name},
		Farm	 => 'StorageManager',
		Rate	 => $re,
		Target	 => $r,
		Percent	 => $x,
		Readings => $i,
		NWorkers => scalar keys %{$self->{clients}},
	  );
  $self->Log( \%h );

# Now check the rate against the desired rate, if one was set!
  return unless $r;
  $s = $self->{Worker}->{Interval};
  $se = $s * $re/$r;
  $smax = $self->{RateStep} || 10; # maximum hike in rate...
  if ( abs($se-$s) > $smax )
  {
    Print "Capping delta-Interval (",abs($se-$s),">$smax)...\n";
    $se = ($se>$s) ? $s+$smax : $s-$smax;
  }
  if ( $stable )
  {
#   Vary the rate less if I am nominally stable...
    $se = ($se+3*$self->{Worker}->{Interval})/4;
  }
  $se = int($se*100)/100;

  if ( $r/$re > 1.1 && $se < 1 ) { $se = 1; } # don't get stuck at zero!
  if ( defined($self->{IntervalMin}) && $se < $self->{IntervalMin} )
  {
    $self->Verbose("Interval pinned at lower boundary\n");
    $se = $self->{IntervalMin};
  }
  if ( defined($self->{IntervalMax}) && $se > $self->{IntervalMax} )
  {
    $self->Verbose("Interval pinned at upper boundary\n");
    $se = $self->{IntervalMax};
  }
  Print "Old interval: $s, new interval $se\n";
  $self->{Worker}->{Interval} = $se;
  my %g = (	MonaLisa => 1,
		Cluster	 => $T0::System{Name},
		Farm	 => 'StorageManager',
		Interval => $se,
	  );
  $self->Log( \%g );
}

sub _started
{
  my ( $self, $kernel, $session ) = @_[ ARG0, KERNEL, SESSION ];
  my %param;

  $self->Debug("TCP server session has started...\n");
  $self->Log("TCP server session has started...\n");
  $self->{Session} = $session->ID;

  $kernel->state( 'send_setup',   $self );
  $kernel->state( 'file_changed', $self );
  $kernel->state( 'broadcast',    $self );
  $kernel->state( 'build_queue',  $self );

  %param = ( File     => $self->{Config},
             Interval => $self->{ConfigRefresh},
             Client   => $self->{Name},
             Event    => 'file_changed',
           );
  $self->{Watcher} = T0::FileWatcher->new( %param );

  %param = ( File     => $self->{SourceFiles},
             Interval => $self->{ConfigRefresh},
             Client   => $self->{Name},
             Event    => 'build_queue',
           );
  $self->{Watcher2} = T0::FileWatcher->new( %param );

  $kernel->yield( 'file_changed' );
  $kernel->yield( 'build_queue' );
}

sub started
{
# Croak "Great, what am I doing here...?\n";
}

sub build_queue
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];

  my @q;
  $self->Debug("build_queue...\n");
  open LIST, $self->{SourceFiles} or
	Croak "open: ",$self->{SourceFiles},": $!\n";
  chomp ( @q  = grep {!/^#/} <LIST> );
  $self->Quiet("Found ",scalar @q," files...\n");

# For existing clients, add any new files to their repertoire...
  foreach ( @queue ) { $q{$_}++; }
  foreach ( @q )
  {
    if ( ! exists($q{$_}) )
    {
      $self->Quiet("Tell clients about \"$_\"...\n");
      $kernel->yield('broadcast', [ "rfcp $_ .", 0 ] );
      $q{$_}++;
    }
  }

# Empty and reform the list...
  @queue = @q;
  if ( ! scalar @queue ) { Croak "Nothing to work with!\n"; }

# Calculate the filesizes
  my %units = ( K => 1024,
		M => 1024 * 1024,
		G => 1024 * 1024 * 1024,
	      );

  foreach ( keys %q )
  {
    s%^.*/%%;
    m%^File-(\d+)([K,M,G])B.dat% or Croak "Don't know about size of \"$_\"\n";
    my $s = $1 * $units{$2};
    $self->{Files}->{$s} = $_;
  }
}

sub broadcast
{
  my ( $self, $args ) = @_[ OBJECT, ARG0 ];
  my ($work,$priority);
  $work = $args->[0];
  $priority = $args->[1] || 0;

  $self->Quiet("broadcasting... ",$work,"\n");

  foreach ( $self->Workers )
  {
    $self->Quiet("Send work=\"",$work,"\", priority=",$priority," to $_\n");
    $self->Workers($_)->enqueue($priority,$work);
  }
}

sub file_changed
{
  my ( $self, $kernel, $file ) = @_[ OBJECT, KERNEL, ARG0 ];
  $self->Quiet("Configuration file \"$self->{Config}\" has changed.\n");
  $self->ReadConfig();
  $kernel->yield( 'send_setup' );
}

sub ReadConfig
{
  my $self = shift;
  my $file = $self->{Config};
  return unless $file;  
  $self->Log("Reading configuration file ",$file);

  $self->{Partners} = { Worker => 'StorageManager::Worker' };
  T0::Util::ReadConfig( $self, , 'StorageManager::Manager' );

  $self->{Interval} = $self->{Interval} || 10;
  foreach ( qw / Watcher Watcher2 / )
  {
    if ( defined $self->{$_} )
    {
      $self->{$_}->Interval($self->{ConfigRefresh});
      $self->{$_}->Options(\%FileWatcher::Params);
    }
  }
}

sub _client_error { reroute_event( (caller(0))[3], @_ ); }
sub client_error
{
  my ( $self, $kernel, $heap ) = @_[ OBJECT, KERNEL, HEAP ];
  my $client = $heap->{client_name};
  $self->Debug($client,": client_error\n");
  $kernel->yield( 'handle_unfinished', $client );
}

sub handle_unfinished
{
  my ( $self, $kernel, $heap, $session, $client ) =
			@_[ OBJECT, KERNEL, HEAP, SESSION, ARG0 ];
  $self->Quiet($session->ID,": $client: handle_unfinished\n");
  return unless $client;
  my $q = $self->Queue($client);
  return unless $q;
  eval
  {
    my ($p,$i,$w) = $q->dequeue_next();
    while ( $i )
    {
      $self->Quiet("Pending Task: Client=$client, work=$w, priority=$p\n");
      ($p,$i,$w) = $q->dequeue_next();
    };
  };

  delete $heap->{client};
}

sub _client_disconnected { reroute_event( (caller(0))[3], @_ ); }
sub client_disconnected
{
  my ( $self, $kernel, $heap ) = @_[ OBJECT, KERNEL, HEAP ];
  my $client = $heap->{client_name};
  $self->Quiet($client,": client_disconnected\n");
  $kernel->yield( 'handle_unfinished', $client );
}

sub send_setup
{
  my ( $self, $kernel, $heap ) = @_[ OBJECT, KERNEL, HEAP ];
  my $client;

  $self->Quiet("Send: Setup to all clients\n");
  my %text = ( 'command' => 'Setup',
               'setup'   => \%StorageManager::Worker,
             );
  $kernel->yield('broadcast', [ \%text, 0 ] );
}

sub send_start
{
  my ( $self, $kernel, $heap ) = @_[ OBJECT, KERNEL, HEAP ];
  my ($client,%text);
  $client = $heap->{client_name};
  $self->Quiet("Send: Start to $client\n");

  my $q = $self->Queue($client);
  foreach ( @queue )
  {
    $self->Quiet("$client: Queue $_\n");
    $q->enqueue(0, "rfcp $_ .");
  }
  %text = ( 'command' => 'Start',);
  $heap->{client}->put( \%text );
}

sub send_work
{
  my ( $self, $kernel, $heap ) = @_[ OBJECT, KERNEL, HEAP ];
  my ($client,%text,$size,$target);

  $client = $heap->{client_name};

# If there's any client-specific stuff in the queue, send that. Otherwise,
# get some generic work...
  my $q = $self->Queue($client);
  my ($priority, $id, $work) = $q->dequeue_next();
  if ( $id )
  {
    $self->Verbose("Queued work: $work\n");
    if ( ref($work) eq 'HASH' )
    {
      %text = ( 'client'	=> $client,
	        'priority'	=> $priority,
	        'interval'	=> $self->{Worker}->{Interval},
              );
      map { $text{$_} = $work->{$_} } keys %$work;
      $heap->{client}->put( \%text );
      return;
    }
  }
  else
  {
    my ($max,$min,$step,@files,);
    $max  = $self->{SizeMax};
    $min  = $self->{SizeMin};
    $step = $self->{SizeStep};
    $size = $self->{Profile}($self);
    
    $target = $self->{SelectTarget}($self);

    my ($lumi,$sminst,$smtot,$uuid,$base);
    $lumi   = $self->{LumiID}      ||  0;
    $sminst = $self->{SMInst}++    ||  0;
    $smtot  = $self->{SMInstances} || 10;
    if ( $sminst >= $smtot )
    {
      $sminst = 0;
      $self->{SMInst} = 1;
      $self->{LumiID} = ++$lumi;
    }
    $uuid = uuid();

    if ( $self->{FilesPerDir} )
    {
      if ( ! defined($self->{file_count}) or
	     $self->{file_count}++ >= $self->{FilesPerDir} )
      {
        $self->{file_count} = 1;
        $self->{base}++;
        $self->{base_dir} = sprintf("%07i",$self->{base});
        my $d = $target . '/' . $self->{base_dir};
        open RFMKDIR, "rfmkdir -p $d |" or warn "rfmkdir: $d: $!\n";
        while ( <RFMKDIR> ) { $self->Debug($_); }
        close RFMKDIR or warn "close rfmkdir: $d: $!\n";
      }
      $target .= '/' . $self->{base_dir};
    }
    $target = $target . "/RAW.$lumi.$sminst.$smtot.$uuid.raw";

    my $x = $size;
    my @s = sort { $b <=> $a } keys %{$self->{Files}}; # Reverse-sorted!
    if ( $x < $s[-1] )
    {
      Croak "$x bytes is smaller than the smallest file! (",$s[-1],")\n";
    }
    while ( $x > 0 && $x > $s[-1] )
    {
      foreach ( @s )
      {
        if ( $_ <= $x )
        {
          push @files, $self->{Files}->{$_};
          $x -= $_;
          last;
        }
      }
    }
    $size -= $x;
    $work = "cat " . join(' ',@files) . " | rfcp - $target";
    $priority = 1;
  }
  $self->Quiet("Send: work=$work, priority=$priority to $client\n");
  %text = ( 'command'	=> 'DoThis',
            'client'	=> $client,
            'work'	=> $work,
	    'priority'	=> $priority,
	    'size'	=> $size,
	    'interval'	=> $self->{Worker}->{Interval},
	    'target'	=> $target,
           );
  $heap->{client}->put( \%text );
}

sub _client_input { reroute_event( (caller(0))[3], @_ ); }
sub client_input
{
  my ( $self, $kernel, $heap, $session, $input ) =
		@_[ OBJECT, KERNEL, HEAP, SESSION, ARG0 ];
  my ( $command, $client );

#  $self->{call_count} = 0 unless defined($self->{call_count});
#  $kernel->call( $session->ID, 'started' ) unless $self->{call_count}++;

  $command = $input->{command};
  $client = $input->{client};

  if ( $command =~ m%HelloFrom% )
  {
    Print "New client: $client\n";
    $heap->{client_name} = $client;
    $self->AddWorker($client);
    $kernel->yield( 'send_setup' );
    $kernel->yield( 'send_start' );
    if ( ! --$self->{MaxWorkers} )
    {
      Print "Telling server to shutdown\n";
      $kernel->post( $self->{Name} => 'shutdown' );
      $self->{Watcher}->RemoveClient($self->{Name});
      $self->{Watcher2}->RemoveClient($self->{Name});
    }
  }

  if ( $command =~ m%SendWork% )
  {
    $kernel->yield( 'send_work' );
  }

  if ( $command =~ m%JobDone% )
  {
    my $work     = $input->{work};
    my $status   = $input->{status};
    my $priority = $input->{priority};
    my $interval = $input->{interval};
    my $size     = $input->{size};
    $self->Quiet("JobDone: work=$work, priority=$priority, interval=$interval, size=$size, status=$status\n");

#   Check rate statistics from the first client onwards...
    if ( !$self->{client_count}++ ) { $kernel->yield( 'set_rate' ); }
    $self->GatherStatistics($size);
    if ( $input->{target} )
    {
      my %h = (	MonaLisa	=> 1,
		Cluster		=> $T0::System{Name},
		Farm		=> 'StorageManager',
		MBWritten	=> $size/1024/1024,
	      );
      $self->Log( \%h );
      my %g = ( InputReady => $input->{target}, Size => $size );
      $self->Log( \%g );
    }
  }

  if ( $command =~ m%Quit% )
  {
    Print "Quit: $command\n";
    my %text = ( 'command'   => 'Quit',
                 'client' => $client,
               );
    $heap->{client}->put( \%text );
  }
}

1;
