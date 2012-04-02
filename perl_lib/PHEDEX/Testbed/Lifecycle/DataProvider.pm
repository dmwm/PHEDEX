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
	  GENERATOR => 'generator --system phedex',
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
$DB::single=1;
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

  $tmp .= sprintf('/Lifecycle-%s-%s-%s-%s.',
		$self->{ME},
                $workflow->{Name},
                $workflow->{Event},
                $payload->{id});
  $tmp =~ s% %_%g;
  $in  = $tmp . 'in';
  $out = $tmp . 'out';
  $log = $tmp . 'log';
  @cmd = split(' ',$cmd);
  push @cmd, ('--in',$in) unless $args->{no_input};
  push @cmd, ('--out',$out);

# TW
# Should not need to protect for $no_input, and should pass $payload to the
# JSON encoder, but the generator doesn't yet understand the full payload
# structure
  if ( ! $args->{no_input} ) {
    $json = encode_json($workflow->{data}); # TODO should be ($payload);
    open IN, ">$in" or $self->Fatal("open $in: $!\n");
    print IN $json;
    close IN;
  }
  $postback = $session->postback($args->{callback},$payload,$in,$out,$log,join(' ',@cmd));
  $timeout = $workflow->{Timeout} || 999;
  $self->{parent}{JOBMANAGER}->addJob( $postback, { TIMEOUT=>$timeout, KEEP_OUTPUT=>1, LOGFILE=>$log }, @cmd);
}

sub makeDataset {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow);

  $self->register('madeDataset');
  $workflow = $payload->{workflow};
  $cmd  = $self->{GENERATOR} . ' --generate datasets ';
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
  my ($payload,$workflow,$in,$out,$log,$result);

  $result = $self->{parent}->post_exec($arg0,$arg1);
  ($payload,$in,$out,$log) = @{$arg0};
  $workflow = $payload->{workflow};

  if ( $workflow->{Dataset} ) {
    $result->[0]{dataset}{name} = $workflow->{Dataset};
  }

  $workflow->{data} = $result;
  $kernel->yield('nextEvent',$payload);
}

sub makeBlocks {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow);

  $self->register('madeBlocks');
  $workflow = $payload->{workflow};
  $cmd  = $self->{GENERATOR} . ' --action add_blocks ';
  $cmd .= "--num $workflow->{Blocks} ";
  
  $self->generate($kernel,
		  $session,
		  $payload,
		  {
		   callback => 'madeBlocks',
		   cmd      => $cmd,
		  }
		  );
}

sub madeBlocks {
  my ($self,$kernel,$session,$arg0,$arg1) = @_[OBJECT,KERNEL,SESSION,ARG0,ARG1];
  my ($payload,$workflow,$in,$out,$log,$result);

  $result = $self->{parent}->post_exec($arg0,$arg1);
  ($payload,$in,$out,$log) = @{$arg0};
  $payload->{workflow}{data} = $result;
  $kernel->yield('nextEvent',$payload);
}

sub makeFiles {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow);

  $self->register('madeFiles');
  $workflow = $payload->{workflow};
  $cmd  = $self->{GENERATOR} . ' --action add_files ';
  $cmd .= "--num $workflow->{Files} ";
  
  $self->generate($kernel,
		  $session,
		  $payload,
		  {
		   callback => 'madeFiles',
		   cmd      => $cmd,
		  }
		  );
}

sub madeFiles {
  my ($self,$kernel,$session,$arg0,$arg1) = @_[OBJECT,KERNEL,SESSION,ARG0,ARG1];
  my ($payload,$workflow,$in,$out,$log,$result);

  $result = $self->{parent}->post_exec($arg0,$arg1);
  ($payload,$in,$out,$log) = @{$arg0};
  $payload->{workflow}{data} = $result;
$self->Logmsg("Data structure is ",Dumper($result));
  $kernel->yield('nextEvent',$payload);
}

1;
