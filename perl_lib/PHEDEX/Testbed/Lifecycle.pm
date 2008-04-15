package PHEDEX::Testbed::Lifecycle;

use strict;
use warnings;
use base 'PHEDEX::Testbed::Agent', 'PHEDEX::Core::Logging';
use Time::HiRes;
use POE;

use Carp;

our @EXPORT = qw( );

our %params =
	(
	  ME			=> 'Lifecycle',
#	  NOFILESYSTEM		=> 1,
	  LIFECYCLE_CONFIG	=> undef,
	  LIFECYCLE_COMPONENT	=> 'PhEDEx::Lifecycle',
	  NInjected		=> 0,
	  NSubscribed		=> 0,
	  NDeleted		=> 0,
	  T1Replicas		=> 0,
	  T2Replicas		=> 0,
	  StatsFrequency	=> 60,
	  Incarnation		=> 1,
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new(%params,@_);
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

#-------------------------------------------------------------------------------
# This sets up the basic state-machinery.
sub _poe_init
{
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];

  $kernel->alias_set( $self->{ME} );

# Declare the injection and other states. Set the stats counter to fire, and
# start watching my configuration file. Things don't actually get rolling until
# the configuration file is read, so yield to that at the end.
  $kernel->state(     'inject', $self);
  $kernel->state('t1subscribe', $self);
  $kernel->state('t2subscribe', $self);
  $kernel->state(   't2delete', $self);
  $kernel->state(  'srcdelete', $self);
  $kernel->state(  'nextEvent', $self );
  $kernel->state(  'lifecycle', $self );

  $kernel->state( 'stats', $self );
  $kernel->delay_set('stats',$self->{StatsFrequency});

  $kernel->state( '_child', $self );
  $kernel->state(  '_stop', $self );

  $kernel->state( 'FileChanged', $self );
  my %watcher_args = (	File     => $self->{LIFECYCLE_CONFIG},
                	Interval => 3,
			Client	 => $self->{ME},
                	Event    => 'FileChanged',
              	     );
  $self->{Watcher} = T0::FileWatcher->new( %watcher_args );
  $kernel->yield('FileChanged');
}

sub _child {}

sub Config { return (shift)->{LIFECYCLE_CONFIG}; }

sub deep_copy {
  my $this = shift;
  if (not ref $this) {
    $this;
  } elsif (ref $this eq "ARRAY") {
    [map deep_copy($_), @$this];
  } elsif (ref $this eq "HASH") {
    +{map { $_ => deep_copy($this->{$_}) } keys %$this};
  } else { die "what type is $_?" }
}

sub nextEvent
{
  my ($self,$kernel,$payload) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($ds,$event,$delay,$block,$msg);
  $ds    = $payload->{dataset};
  $msg = "nextEvent: $ds->{Name}:";
  if ( $block = $payload->{block} ) { $msg .= ' ' . $block->{block}; }
  $event = shift(@{$payload->{events}});
  if ( !$event )
  {
    $self->Logmsg("$msg cycle ends") if $self->{Verbose};
    return;
  } 
  $delay = $ds->{$event} if exists($ds->{$event});
  my $txt = join(', ',@{$payload->{events}});
  if ( $delay && $self->{Jitter} ) { $delay *= ( 1 + rand($self->{Jitter}) ); }
  if ( $delay )
  {
    if ( $self->{CycleSpeedup} ) { $delay /= $self->{CycleSpeedup}; }
    $self->Dbgmsg("$msg $event $delay. $txt") if $self->{Debug};
    $kernel->delay_set($event,$delay,$payload);
  }
  else
  {
    $self->Dbgmsg("$msg $event (now). $txt") if $self->{Debug};
    $kernel->yield($event,$payload);
  }
}
 
sub FileChanged
{
  my ($self,$kernel) = @_[ OBJECT, KERNEL ];
  $self->Logmsg("\"",$self->{LIFECYCLE_CONFIG},"\" has changed...");
  $self->ReadConfig();
  eval {
    $self->connectAgent() if !$self->{Dummy};
  };
  $self->Fatal($@) if $@;

  if ( $self->{DoInjection} )
  {
    $self->Logmsg("Beginning new cycle...");
    my $ds;
    foreach $ds ( @{$self->{Datasets}} )
    {
      next unless $ds->{InUse};
      $self->Logmsg("Beginning lifecycle for $ds->{Name}...");
      $kernel->delay_set('lifecycle',0.01,$ds);
    }
  }
}

sub lifecycle
{
  my ($self,$kernel,$ds) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($event,$delay,@events);
  push @events, @{$ds->{events}};
  return unless $ds->{NCycles}--;
  return unless $self->{Incarnation} == $ds->{Incarnation};

  my $payload = {
		  'dataset' => $ds,
		  'events'  => [@events],
		};
  $kernel->yield('nextEvent',$payload);

  $event = $events[0];
  return unless $event;
  $delay = $ds->{CycleTime};
  return unless $delay;
  if ( $self->{Jitter} ) { $delay *= ( 1 + rand($self->{Jitter}) ); }
  if ( $self->{CycleSpeedup} ) { $delay /= $self->{CycleSpeedup}; }
  $self->Dbgmsg("lifecycle: $delay") if $self->{Debug};
  $kernel->delay_set('lifecycle',$delay,$ds) if $delay;
}

sub ReadConfig
{
  my $self = shift;
  my $file = shift || $self->{LIFECYCLE_CONFIG};
  my $hash = $self->{LIFECYCLE_COMPONENT};
  return unless $file;

  T0::Util::ReadConfig($self,$hash,$file);

# Sanitise the datasets, setting defaults etc
  my ($ds);
  $self->{DatasetDefaults}  = {} unless $self->{DatasetDefaults};
  $self->{DataflowDefaults} = {} unless $self->{DataflowDefaults};
  $self->{Incarnation}++; # This is used to allow old stuff to die out
  foreach $ds ( @{$self->{Datasets}} )
  {
    $ds->{Incarnation} = $self->{Incarnation};
    push @{$ds->{events}}, @{$self->{Dataflow}{$ds->{Dataflow}}};

#   Workflow defaults fill in for undefined values
    foreach ( keys %{$self->{DataflowDefaults}{$ds->{Dataflow}}} )
    {
      if ( ! defined( $ds->{$_} ) )
      {
        $self->Logmsg("Setting default for $ds->{Name}($_)") if $self->{Verbose};
        $ds->{$_} = $self->{DataflowDefaults}{$ds->{Dataflow}}{$_};
      }
    }

#   Global defaults fill in for everything else
    foreach ( keys %{$self->{DatasetDefaults}} )
    {
      if ( ! defined( $ds->{$_} ) )
      {
        $self->Logmsg("Setting default for $ds->{Name}($_)") if $self->{Verbose};
        $ds->{$_} = $self->{DatasetDefaults}{$_};
      }
    }

  }

  no strict 'refs';
  $self->Log( \%{$self->{LIFECYCLE_COMPONENT}} );

  if ( defined($self->{Watcher}) )
  {
    $self->{Watcher}->Interval($self->ConfigRefresh);
#   $self->{Watcher}->Options( %FileWatcher::Params);
  }
}

sub inject
{
  my ( $self, $kernel, $payload ) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($ds,$events);
  $ds     = $payload->{dataset};
  $events = $payload->{events};

  return unless $ds->{Incarnation} == $self->{Incarnation};

  my $block = $self->makeBlock($ds);
  my $xmlfile = 'injection.xml';
  $self->Logmsg("Inject $ds->{Name}($block->{block}) at $ds->{InjectionSite}") unless $self->{Quiet};
  if ( ! $self->{Dummy} )
  {
    $self->makeXML($block,$xmlfile);
#   my $cmd = $ENV{PHEDEX_SCRIPTS} . '/Toolkit/Request/TMDBInject';
#   $cmd .= ' -db ' . $ENV{PHEDEX_DBPARAM};
    my $cmd = '/build/wildish/phedex/Validation/PHEDEX/Toolkit/Request/TMDBInject';
    $cmd .= ' -db /build/wildish/phedex/Validation/PHEDEX/Testbed/ProductionScaling/DBParam:Validation';
    $cmd .= ' -verbose' if $self->{Verbose};
    $cmd .= ' -nodes ' . $ds->{InjectionSite};
    $cmd .= ' -filedata ' . $xmlfile;

    open INJECT, "$cmd 2>&1 |" or die "$cmd: $!\n";
    while ( <INJECT> ) { $self->Logmsg($_) if $self->{Debug}; }
    close INJECT or die "close: $cmd: $!\n";
    die "unlink: $xmlfile: $!\n" unless unlink $xmlfile;
  }
  $self->{NInjected}++;
  $self->{replicas}{$ds->{InjectionSite}}++;
  $payload->{block} = $block;
  $kernel->yield( 'nextEvent', $payload );
}

sub t1subscribe
{
  my ( $self, $kernel, $payload ) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($ds,$events,$block);
  $ds     = $payload->{dataset};
  $events = $payload->{events};
  $block  = $payload->{block};
# $self->Logmsg("T1Subscribe $block->{block} for $ds->{Name}") unless $self->{Quiet};
  my $dsts = $ds->{T1s};

  if ( ! $dsts )
  {
#   Take all T1 MSS nodes by default
    my @t1s = grep('T1_*_MSS', keys %{$self->{NodeIDs}});
    $dsts = \@t1s;
    $ds->{T1s} = \@t1s;
  }

  my $delay = 0.1;
  foreach ( @{$dsts} )
  {
    my $p = deep_copy($payload);
    $p->{T1} = $_;
    $self->Logmsg("T1Subscription  for $block->{block} to node $_")
	 unless $self->{Quiet};
    $self->subscribeBlock($ds,$block,$_);
    $self->{replicas}{$_}++;
    $self->{T1Replicas}++;
    $self->{NSubscribed}++;
    $kernel->delay_set( 'nextEvent', $delay, $p );
    $delay += 0.1;
  }
}

sub t2subscribe
{
  my ( $self, $kernel, $payload ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
  my ($ds,$events,$block,$t1);
  $ds     = $payload->{dataset};
  $events = $payload->{events};
  $block  = $payload->{block};
  $t1     = $payload->{T1};

  my $dsts = $ds->{T2s};
  if ( ! $dsts ) { $dsts = $self->{T2AssocMap}{$t1}; }
# Not having an associated T2 is not a crime...
  return unless $dsts;

  my $delay = 0.1;
  foreach ( @{$dsts} )
  {
    my $p = deep_copy($payload);
    $p->{T2} = $_;
    $self->Logmsg("T2Subscription for $block->{block} to node $_")
	 unless $self->{Quiet};
    $self->subscribeBlock($ds,$block,$_);
    $self->{replicas}{$_}++;
    $self->{T2Replicas}++;
    $self->{NSubscribed}++;
    $kernel->delay_set( 'nextEvent', $delay, $p );
    $delay += 0.1;
  }
}

sub srcdelete
{
  my ( $self, $kernel, $payload ) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($ds,$events,$block,$src);
  $ds     = $payload->{dataset};
  $events = $payload->{events};
  $block  = $payload->{block};
  $src    = $ds->{InjectionSite};

  $self->deleteBlock($ds,$block,$src);
  $self->{replicas}{$src}--;
  $self->{NDeleted}++;
  $self->Logmsg("Deleting $block->{block} from node $src")
	unless $self->{Quiet};
  $kernel->yield( 'nextEvent', $payload );
}

sub t2delete
{
  my ( $self, $kernel, $payload ) = @_[ OBJECT, KERNEL, ARG0 ];
  my ($ds,$events,$block,$t2);
  $ds     = $payload->{dataset};
  $events = $payload->{events};
  $block  = $payload->{block};
  $t2     = $payload->{T2};

  $self->deleteBlock($ds,$block,$t2);
  $self->{replicas}{$t2}--;
  $self->{T2Replicas}--;
  $self->{NDeleted}++;
  $self->Logmsg("Deleting $block->{block} from node $t2")
	unless $self->{Quiet};
  $kernel->yield( 'nextEvent', $payload );
}

sub _stop
{
  my ( $self, $kernel, $force ) = @_[ OBJECT, KERNEL, ARG0 ];
# $kernel->delay_set('_stop',1) unless $force;
# return unless $self->{StopOnIdle} || $force;

  $self->Logmsg('nothing left to do, may as well shoot myself');
  $self->{Watcher}->RemoveClient( $self->{ME} );
  $self->stats();
  $kernel->delay('stats');
  $self->Logmsg('stopping now...');
  $self->doStop();
}

sub stats
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  $self->Logmsg('Statistics: NInjected=',$self->{NInjected},
		' NSubscribed=',$self->{NSubscribed},
                ' NDeleted=',$self->{NDeleted},
		' T1Replicas=',$self->{T1Replicas},
                ' T2Replicas=',$self->{T2Replicas});

  return unless $self->{replicas};
  my $txt = join(' ',
		map { "$_=" . $self->{replicas}{$_} }
		sort keys %{$self->{replicas}}
		);
  $self->Logmsg('NReplicas: ',$txt);
  return unless $kernel;
  $kernel->delay_set('stats',$self->{StatsFrequency});
}

#-------------------------------------------------------------------------------
# This is the bit that creates blocks and manipulates TMDB
sub subscribeBlock
{
  my ( $self, $ds, $block, $node ) = @_;
  return if $self->{Dummy};

  my $nodeid = $self->{NodeID}{$node};
  my $h;
  $h->{BLOCK}		= $block->{block};
  $h->{node}		= $nodeid;
  $h->{priority}	= $ds->{Priority};
  $h->{is_move}		= $ds->{IsMove};
  $h->{is_transient}	= $ds->{IsTransient};
  $h->{time_create}	= $block->{created};
  $self->insertSubscription( $h );
  $self->{DBH}->commit;
}

sub deleteBlock
{
  my ( $self, $ds, $block, $node ) = @_;
  return if $self->{Dummy};

  my $nodeid = $self->{NodeID}{$node};
  my $h;
  $h->{BLOCK}		= $block->{block};
  $h->{node}		= $nodeid;
  $h->{time_request}	= time;
  $self->insertBlockDeletion( $h );
  $self->{DBH}->commit;
}

sub makeBlock
{
  my ($self,$ds) = @_;
  my ($h,$blockid);

  my $now = time;
  $blockid = $now - 1207000800;
  $blockid = sprintf("%08x",$blockid);
  $h->{dbs} = $self->{DBS} || "test";
  $h->{dls} = $self->{DLS} || "lfc:unknown";
  $h->{created}     = $now;
  $h->{DsetIsOpen}  = $ds->{IsOpen};
  $h->{BlockIsOpen} = $ds->{IsOpen};
  $h->{IsTransient} = $ds->{IsTransient};

  $h->{dataset} = $ds->{Name};
  $h->{block} = $ds->{Name} . "#$blockid";
  for my $n_file (1..$ds->{NFiles})
  {
    my $lfn = $ds->{Name}. "-${blockid}-${n_file}";
    my $filesize;
#   $filesize = int(rand() * 2 * (1024**3));
    my $mean = $ds->{FileSizeMean} || 2.0;
    my $sdev = $ds->{FileSizeStdDev} || 0.2;
    $filesize = int(gaussian_rand($mean, $sdev) *  (1024**3)); #
    my $cksum = 'cksum:'. int(rand() * (10**10));
    push @{$h->{files}}, { lfn => $lfn, size => $filesize, cksum => $cksum };
  };
  return $h;
}

sub makeXML
{
  my ($self,$h,$xmlfile) = @_;

  my ($dbs,$dls,$dataset,$block,$files,$disopen,$bisopen,$istransient);
  $dbs = $h->{dbs};
  $dls = $h->{dls};
  $dataset     = $h->{dataset};
  $block       = $h->{block};
  $disopen     = $h->{DsetIsOpen};
  $bisopen     = $h->{BlockIsOpen};
  $istransient = $h->{IsTransient};
  if ( ! defined($xmlfile) )
  {
    $xmlfile = $dataset;
    $xmlfile =~ s:^/::;  $xmlfile =~ s:/:-:g; $xmlfile .= '.xml';
  }

  open XML, '>', $xmlfile or die $!;
  print XML qq{<dbs name="$dbs"  dls="$dls">\n};
  print XML qq{\t<dataset name="$dataset" is-open="$disopen" is-transient="$istransient">\n};
  print XML qq{\t\t<block name="$block" is-open="$bisopen">\n};
  for my $file ( @{$h->{files}} )
  {
    my $lfn = $file->{lfn} || die "lfn not defined\n";
    my $size = $file->{size} || die "filesize not defined\n";
    my $cksum = $file->{cksum} || die "cksum not defined\n";
    print XML qq{\t\t\t<file lfn="$lfn" size="$size" checksum="$cksum"/>\n};
  }
  print XML qq{\t\t</block>\n};
  print XML qq{\t</dataset>\n};
  print XML qq{</dbs>\n};
  close XML;

  $self->Logmsg("Wrote injection file to $xmlfile") if $self->{Debug};
}

sub gaussian_rand {
    my ($mean, $sdev) = @_;
    $mean ||= 0;  $sdev ||= 1;
    my ($u1, $u2);  # uniformly distributed random numbers
    my $w;          # variance, then a weight
    my ($g1, $g2);  # gaussian-distributed numbers

    do {
        $u1 = 2 * rand() - 1;
        $u2 = 2 * rand() - 1;
        $w = $u1*$u1 + $u2*$u2;
    } while ( $w >= 1 );

    $w = sqrt( (-2 * log($w))  / $w );
    $g2 = $u1 * $w;
    $g1 = $u2 * $w;

    $g1 = $g1 * $sdev + $mean;
    $g2 = $g2 * $sdev + $mean;
    # return both if wanted, else just one
    return wantarray ? ($g1, $g2) : $g1;
}

1;
