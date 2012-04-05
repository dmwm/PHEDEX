package PHEDEX::Testbed::Lifecycle::DataProvider;
#
# Interact with the lifecycle-dataprovider package
use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use POE qw( Queue::Array );
use JSON::XS;
use Data::Dumper;

our %params = (
	  DATAPROVIDER => 'dataprovider --system phedex',
	);

sub new {
  my $proto = shift;
  my $parent = shift;
  my $workflow = shift;
  my $class = ref($proto) || $proto;

  my $self = $class->SUPER::new();
  $self->{parent} = $parent;

  my $package = __PACKAGE__;
  $package =~ s%^$workflow->{Namespace}::%%;
  $self->{ME} = $package;

  my $p = $workflow->{$package};
  map { $self->{$_} = $params{$_} } keys %params;
  map { $self->{$_} = $p->{$_} } keys %{$p};

  bless $self, $class;

  return $self;
}

sub register { PHEDEX::Testbed::Lifecycle::Lite::register(@_); }

sub generate {
  my ($self,$kernel,$session,$payload,$args) = @_;
  my ($workflow,@cmd,$cmd,$json,$postback,$in,$out,$log,$tmp,$timeout);
  $self->{PARENT_SESSION} = $session unless $self->{PARENT_SESSION};
  $cmd = $args->{cmd};

  $workflow = $payload->{workflow};
  $tmp = $workflow->{TmpDir};
  if ( ! -d $tmp ) {
    mkpath($tmp) || $self->Fatal("Cannot mkdir $tmp: $!\n");
  }

  $tmp = $self->{parent}->tmpFile($payload);
  ($in,$out,$log) = map { $tmp . $_ } ( 'in', 'out', 'log' );
  @cmd = split(' ',$cmd);
  push @cmd, ('--in',$in) unless $args->{no_input};
  push @cmd, ('--out',$out);

# TW
# Should not need to protect for $no_input, and should pass $payload to the
# JSON encoder, but the dataprovider doesn't yet understand the full payload
# structure
  if ( ! $args->{no_input} ) {
    $json = encode_json($workflow->{data}); # TODO should be ($payload);
    open IN, ">$in" or $self->Fatal("open $in: $!\n");
    print IN $json;
    close IN;
  }

  $self->register($args->{callback});
  $postback = $session->postback($args->{callback},$payload,$in,$out,$log,join(' ',@cmd));
  $timeout = $workflow->{Timeout} || 999;
  $self->{parent}{JOBMANAGER}->addJob( $postback, { TIMEOUT=>$timeout, KEEP_OUTPUT=>1, LOGFILE=>$log }, @cmd);
}

sub makeDataset {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow);

  $self->register('madeDataset');
  $workflow = $payload->{workflow};
  $cmd  = $self->{DATAPROVIDER} . ' --generate datasets ';
  $cmd .= "--num $workflow->{Datasets} ";
  
  $self->generate($kernel,
		  $session,
		  $payload,
		  {
		   callback => 'madeDataset',
		   cmd      => $cmd,
		   no_input => 1,
		  }
		  );
}

sub madeDataset {
  my ($self,$kernel,$session,$arg0,$arg1) = @_[OBJECT,KERNEL,SESSION,ARG0,ARG1];
  my ($payload,$workflow,$in,$out,$log,$result,$name,$i);

  $result = $self->{parent}->post_exec($arg0,$arg1);
  ($payload,$in,$out,$log) = @{$arg0};
  $workflow = $payload->{workflow};

# TW Override the dataset name explicitly!
  if ( $workflow->{Dataset} ) {
    $i = 0;
    foreach ( @{$result} ) {
      $_->{dataset}{name} = sprintf($workflow->{Dataset},$i++);
    }
  }

# TW Override the DBS name explicitly!
  if ( $workflow->{DBS} ) {
    foreach ( @{$result} ) {
      $_->{dataset}{dbs_name} = $workflow->{DBS};
    }
  }

  $workflow->{data} = $result;
  $kernel->yield('nextEvent',$payload);
}

sub makeBlocks {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow);

  $workflow = $payload->{workflow};
  $cmd  = $self->{DATAPROVIDER} . ' --action add_blocks ';
  $cmd .= "--num $workflow->{Blocks} ";
  
  $self->generate($kernel,
		  $session,
		  $payload,
		  {
		   callback => 'standardCallback',
		   cmd      => $cmd,
		  }
		  );
}

sub standardCallback {
  my ($self,$kernel,$session,$arg0,$arg1) = @_[OBJECT,KERNEL,SESSION,ARG0,ARG1];
  $arg0->[0]->{workflow}{data} = $self->{parent}->post_exec($arg0,$arg1);
  $kernel->yield('nextEvent',$arg0->[0]);
}

sub makeFiles {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow);

  $workflow = $payload->{workflow};
  $cmd  = $self->{DATAPROVIDER} . ' --action add_files ';
  $cmd .= "--num $workflow->{Files} ";
  
  $self->generate($kernel,
		  $session,
		  $payload,
		  {
		   callback => 'standardCallback',
		   cmd      => $cmd,
		  }
		  );
}

#sub madeFiles {
#  my ($self,$kernel,$session,$arg0,$arg1) = @_[OBJECT,KERNEL,SESSION,ARG0,ARG1];
#  $arg0->[0]->{workflow}{data} = $self->{parent}->post_exec($arg0,$arg1);
#  $kernel->yield('nextEvent',$payload);
#}

sub addData {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow,$event,$id,$datasets,$blocks,$files,$dataset,$dsname);

  $workflow = $payload->{workflow};
  $event    = $workflow->{Event};
  $id       = $payload->{id};
  $datasets = $workflow->{Datasets};
  $blocks   = $workflow->{Blocks};
  $files    = $workflow->{Files};
  $dataset  = $workflow->{data}[0]{dataset};
  $dsname   = $dataset->{name};

  $workflow->{InjectionsThisBlock} ||= 0;
  $workflow->{BlocksThisDataset}   ||= 1; # Assume it already has a block
# TW N.B. Assume I have only one dataset!
  $self->Dbgmsg("$workflow->{BlocksThisDataset} blocks, $workflow->{InjectionsThisBlock} injections this block, $workflow->{BlocksPerDataset} blocks/dataset, $workflow->{InjectionsPerBlock} injections/block");

  $workflow->{InjectionsThisBlock}++;
  if ( $workflow->{InjectionsThisBlock} >= $workflow->{InjectionsPerBlock} ) {
#   These blocks are full. Close them, and go on to the next set
    foreach ( @{$dataset->{blocks}} ) {
      $_->{block}{'is-open'} = 'n';
    }
    $self->Dbgmsg("addData ($dsname): close one or more blocks");
    $workflow->{BlocksThisDataset}++;
    if ( $workflow->{BlocksThisDataset} > $workflow->{BlocksPerDataset} ) {
      $self->Logmsg("addData ($dsname): all blocks are complete, terminating.");
      $kernel->yield('nextEvent',$payload);
      return;
    }

#   Start a new block
    $self->Dbgmsg("addData ($dsname): create one or more new blocks");
    $workflow->{InjectionsThisBlock} = 0;
    push @{$payload->{events}}, $event;
    $kernel->call($session,'makeBlocks',$payload);
    return;
  }

# Add files, be it to a new or an existing block
  $self->Dbgmsg("addData ($dsname): add files to block(s)");
  $kernel->call($session,'makeFiles',$payload);
  $self->postPush('addData',$payload);
  return;
}

sub postPush {
  my ($self,$event,$payload) = @_;
  my ($post,@events);
  return unless $post = $self->{$event};
  return unless @events = @{$post->{addEvents}};
  foreach ( @events ) {
    push @{$payload->{events}}, $_; # TW TODO How to do this? ('Inject', $event);
  }
}

1;
