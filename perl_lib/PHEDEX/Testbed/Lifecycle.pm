package PHEDEX::Testbed::Lifecycle;

use strict;
use warnings;
use base 'PHEDEX::Testbed::Agent', 'PHEDEX::Core::Logging';
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
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new(%params,@_);
  bless $self, $class;
  $self->ReadConfig();
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
# This is the state-machinery.
sub _poe_init
{
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];

  $kernel->alias_set( $self->{ME} );

# Declare the injection and other states. Set it to fire up after giving
# time for other things to initialise and settle down
  $kernel->state(     'injection', $self);
  $kernel->state('t1subscription', $self);
  $kernel->state('t2subscription', $self);
  $kernel->state(      'deletion', $self);

  if ( $self->{InjectionRate} )
  {
    $kernel->delay_set('injection', 2 )
  }
  else
  {
    $kernel->yield('_stop');
  }

  $kernel->state( 'stats', $self);
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

sub FileChanged
{
  my ($self,$kernel) = @_[ OBJECT, KERNEL ];
  $self->Logmsg("\"",$self->{LIFECYCLE_CONFIG},"\" has changed...\n");
  my $old_rate = $self->{InjectionRate};
  $self->ReadConfig();
  if ( $self->{InjectionRate} && !$old_rate )
  {
    $self->Logmsg("Resuming injection...");
    $kernel->yield('injection');
  }
}

sub ReadConfig
{
  my $self = shift;
  my $file = shift || $self->{LIFECYCLE_CONFIG};
  my $hash = $self->{LIFECYCLE_COMPONENT};
  return unless $file;

  T0::Util::ReadConfig($self,$hash,$file);
  if ( $self->{InjectionRate} && $self->{InjectionRate} < 1 )
  {
    $self->Log("Injection rate should be >= 1, setting it to 1");
    $self->{InjectionRate}=1;
  }
  no strict 'refs';
  $self->Log( \%{$self->{LIFECYCLE_COMPONENT}} );

  if ( defined($self->{Watcher}) )
  {
    $self->{Watcher}->Interval($self->ConfigRefresh);
    $self->{Watcher}->Options( %FileWatcher::Params);
  }
}

sub injection
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  my ($dataset,$blockid,$files);
  $dataset = 'dataset_' . T0::Util::bin_table($PhEDEx::Lifecycle{DatasetRates});
  $blockid = time - 1207000800;
  $blockid = sprintf("%08x",$blockid);

  my $h;
  $files = $self->{DatasetNFiles};

# $h = $PhEDEx::Lifecycle{Files};
# $files = T0::Util::profile_table($h->{Min},$h->{Max},$h->{Step},$h->{Table});
  $h = {
                BlockInjected => 1,
                Dataset => $dataset,
                Blocks  => $blockid,
                Files   => $files,
       };
  my $block = $self->makeBlock($dataset,$blockid,$files);
  $self->injectBlock($block);
  $self->{NInjected}++;
  $self->Log( $h ) if $self->{Verbose};
  $self->Log( Injecting => $block->{block} ) unless $self->{Quiet};
  $kernel->delay_set( 'injection', $self->{InjectionRate} ) if $self->{InjectionRate};
  $kernel->delay_set( 't1subscription', $self->{T1SubscriptionDelay}, $block ) if $self->{T1SubscriptionDelay};
}

sub t1subscription
{
  my ( $self, $kernel, $block ) = @_[ OBJECT, KERNEL, ARG0 ];
  my $dsts = $self->{T1SubscriptionMap}{$block->{dataset}};

  if ( ! $dsts )
  {
    $self->Alert("No subscription map for dataset=",$block->{dataset});
    $kernel->yield('_stop');
    return;
  }

  foreach ( @{$dsts} )
  {
    $self->Log( T1Subscription => { node => $_, block => $block->{block} } )
	 unless $self->{Quiet};
    $self->subscribeBlock($block,$_);
    $self->{replicas}{$_}++;
    $self->{T1Replicas}++;
    $self->{NSubscribed}++;
    $kernel->delay_set( 't2subscription', $self->{T2SubscriptionDelay}, $block, $_ ) if $self->{T2SubscriptionDelay};
  }
}

sub t2subscription
{
  my ( $self, $kernel, $block, $t1 ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
  my $dsts = $self->{T2AssocMap}{$t1};

  return unless $dsts;

  foreach ( @{$dsts} )
  {
    $self->Log( T2Subscription => { node => $_, block => $block->{block} } )
	 unless $self->{Quiet};
    $self->subscribeBlock($block,$_);
    $self->{replicas}{$_}++;
    $self->{T2Replicas}++;
    $self->{NSubscribed}++;
    $kernel->delay_set( 'deletion', $self->{T2DeletionDelay}, $block, $_ );
  }
}

sub deletion
{
  my ( $self, $kernel, $block, $node ) = @_[ OBJECT, KERNEL, ARG0, ARG1 ];
  $self->deleteBlock($block);
  $self->{replicas}{$node}--;
  $self->{T2Replicas}--;
  $self->{NDeleted}++;
  $self->Log( Deleting => { node => $node, block => $block->{block} } )
	unless $self->{Quiet};

  if ( !$self->{T2Replicas} && !$self->{InjectionRate} )
  {
    $kernel->yield('_stop');
  }
}

sub _stop
{
  my ( $self, $kernel) = @_[ OBJECT, KERNEL ];
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
$DB::single=1;
  my $txt = join(' ',
		map { "$_=" . $self->{replicas}{$_} }
		sort { $a <=> $b } keys %{$self->{replicas}}
		);
  $self->Logmsg('NReplicas: ',$txt);
  return unless $kernel;
  $kernel->delay_set('stats',$self->{StatsFrequency});
}

#-------------------------------------------------------------------------------
# This is the bit that creates blocks and manipulates TMDB
sub injectBlock
{
  my ( $self, $block ) = @_;
  return if $self->{Dummy};
}

sub subscribeBlock
{
  my ( $self, $block, $node ) = @_;
  return if $self->{Dummy};
}

sub deleteBlock
{
  my ( $self, $block, $node ) = @_;
  return if $self->{Dummy};
}

sub makeBlock
{
  my ($self,$dataset,$block,$files) = @_;
  my $h;

  $h->{dbs} = $self->{DBS} || "test";
  $h->{dls} = $self->{DLS} || "lfc:unknown";
  $h->{'dis-open'} = 'n';
  $h->{'bis-open'} = 'n';
  $h->{'is-transient'} = 'n';

  $h->{dataset} = $dataset;
  $h->{block} = $dataset . "#$block";
  for my $n_file (1..$files)
  {
    my $lfn = $dataset. "-${block}-${n_file}";
    my $filesize = int(rand() * 2 * (1024**3));
    my $cksum = 'cksum:'. int(rand() * (10**10));
    push @{$h->{files}}, { lfn => $lfn, size => $filesize, cksum => $cksum };
  };
  return $h;
}

sub makeXML
{
# This isn't actually used...
  my ($self,$h) = @_;

  my ($dbs,$dls,$dataset,$block,$files,$disopen,$bisopen,$istransient);
  $dbs = $h->{dbs};
  $dls = $h->{dls};
  $dataset     = $h->{dataset};
  $block       = $h->{block};
  $disopen     = $h->{'dis-open'};
  $bisopen     = $h->{'bis-open'};
  $istransient = $h->{'is-transient'};
  my $xmlfile = $dataset;
  $xmlfile =~ s:^/::;  $xmlfile =~ s:/:-:g; $xmlfile .= '.xml';

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

  $self->Logmsg("Wrote injection file to $xmlfile");
}

1;
