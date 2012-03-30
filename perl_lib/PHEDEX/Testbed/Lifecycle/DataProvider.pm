package PHEDEX::Testbed::Lifecycle::DataProvider;
#
# Interact with the lifecycle-dataprovider package
use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use POE qw( Queue::Array );
use Clone qw(clone);
use JSON::XS;
use Data::Dumper;

our %params = (
	  generator => 'generator --system phedex',
	);

sub new
{
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
  map { $self->{params}{uc $_} = $params{$_} } keys %params;
  map { $self->{params}{uc $_} = $p->{$_} } keys %{$p};
  map { $self->{$_} = $p->{$_} } keys %{$p};

  bless $self, $class;

  return $self;
}

sub generate
{
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
  $json = encode_json($payload);
  open IN, ">$in" or $self->Fatal("open $in: $!\n");
  print IN $json;
  close IN;
  $postback = $session->postback($args->{callback},$workflow,$payload,$in,$out,$log);
  $timeout = $workflow->{Timeout} || 999;
  $self->{parent}{JOBMANAGER}->addJob( $postback, { TIMEOUT=>$timeout, KEEP_OUTPUT=>1, LOGFILE=>$log }, @cmd);
}

sub makeDataset
{
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($cmd,$workflow);

  if ( ! $self->{registered}{madeDataset}++ ) {
    $kernel->state( 'madeDataset', $self, 'madeDataset' );
  }

  $workflow = $payload->{workflow};
  $cmd  = $self->{params}{GENERATOR} . ' --generate datasets ';
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

sub madeDataset
{
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
$self->Logmsg('Now you have to do something with the output!');
$DB::single=1;
#  my ($agents,$agent,$re,$tmp);
#
#  $self->Logmsg("got: Agents($target,",Data::Dumper->Dump([$params]),")\n");
#  $agents = $obj->{PHEDEX}{NODE};
#  foreach $agent (@{$agents}) {
#    next if ( $agent->{AGENT}[0]{LABEL} =~ m%^mgmt-%  && $agent->{NODE} ne 'T0_CH_CERN_Export' );
#    foreach ( @{$agent->{AGENT}} ) {
#      $tmp = clone $payload;
#      $tmp->{workflow}{Agent} = $_;
#      foreach ( qw/ HOST NAME NODE / ) { $tmp->{workflow}{Agent}{$_} = $agent->{$_}; }
#      $kernel->yield('nextEvent',$tmp);
#    }
#  }
}

1;
