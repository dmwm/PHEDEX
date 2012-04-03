package PHEDEX::Testbed::Lifecycle::Datasvc;
use strict;
use warnings;
use base 'PHEDEX::Testbed::Lifecycle::UA', 'PHEDEX::Core::Logging';
use POE qw( Queue::Array );
use Clone qw(clone);
use Data::Dumper;
use PHEDEX::CLI::UserAgent;

our %params = (
#	  cert_file => undef,
#	  key_file  => undef,
	  url       => 'https://cmsweb.cern.ch/phedex/datasvc',
	  instance  => 'prod',
	  format    => 'perl',
	  timeout   => 60,
#	  proxy     => undef,
#	  ca_file   => undef,
#	  ca_dir    => undef,
#	  nocert    => undef,
#	  Verbose   => undef,
#	  Debug     => undef,
	);

sub new {
  my $proto = shift;
  my $parent = shift;
  my $workflow = shift;
  my $class = ref($proto) || $proto;

  my $self = $class->SUPER::new( $parent );

  my $package = __PACKAGE__;
  $package =~ s%^$workflow->{Namespace}::%%;

  my $p = $workflow->{$package};
  map { $self->{params}{uc $_} = $params{$_} } keys %params;
  map { $self->{params}{uc $_} = $p->{$_} } keys %{$p};
  map { $self->{$_} = $p->{$_} } keys %{$p};
  $self->{UA} = PHEDEX::CLI::UserAgent->new( %{$self->{params}} );

  bless $self, $class;

  return $self;
}

sub getFromDatasvc {
  my ($self,$kernel,$session,$payload,$args) = @_;
  my ($target,$workflow,$api,$callback,$params,$method);
  $self->{PARENT_SESSION} = $session unless $self->{PARENT_SESSION};
  $method = $args->{method} || 'get';
  $params = $args->{params} || {};
  $callback = $args->{callback};

  $workflow = $payload->{workflow};
  $self->{UA}->CALL($args->{api});
  $target = $self->{UA}->target;
  if ( $callback && ! $self->{_callbacks}{$callback}++ ) {
    $kernel->state($callback,$self);
  }
  $kernel->post($self->{Alias},'start_task',{
				  payload	=> $payload,
				  method	=> $method,
				  target	=> $target,
				  params	=> $params,
				  callback	=> $callback,
				});
}

sub makeXML {
  my ($self,$data) = @_;
  my (@xml,$dbs,$i,$j,$k,$dataset,$block,$file);

  $dbs = $dbs || $data->[0]{dataset}{dbs_name} || $data->{dbs_name} || $dbs;
  @xml = (
            "<data version=\"2.0\">",
            "  <dbs name=\"$dbs\" dls=\"dbs\">"
          );
  foreach $i ( @{$data} ) {
    $dataset = $i->{dataset};
    push @xml, "    <dataset name=\"$dataset->{name}\" is-open=\"$dataset->{'is-open'}\">";
    foreach $j ( @{$dataset->{blocks}} ) {
      $block = $j->{block};
      push @xml, "      <block name=\"$block->{name}\" is-open=\"$block->{'is-open'}\">";
      foreach $k ( @{$block->{files}} ) {
        $file = $k->{file};
        push @xml, "      <file name=\"$file->{name}\" bytes=\"$file->{bytes}\" checksum=\"$file->{checksum}\" />";
      }
      push @xml, "      </block>";
    }
    push @xml, "    </dataset>";
  } 
  push @xml, "  </dbs>";
  push @xml, "</data>";

  return join("\n",@xml);
}

sub Agents {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api	  => 'agents',
			 callback => 'gotAgents',
			 params	  => { node => $payload->{workflow}{Node} }
			}
			);
}

sub gotAgents {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
  my ($agents,$agent,$re,$tmp);

  $self->Logmsg("got: Agents($target,",Data::Dumper->Dump([$params]),")\n");
  $agents = $obj->{PHEDEX}{NODE};
  foreach $agent (@{$agents}) {
    next if ( $agent->{AGENT}[0]{LABEL} =~ m%^mgmt-%  && $agent->{NODE} ne 'T0_CH_CERN_Export' );
    foreach ( @{$agent->{AGENT}} ) {
      $tmp = clone $payload;
      $tmp->{workflow}{Agent} = $_;
      foreach ( qw/ HOST NAME NODE / ) { $tmp->{workflow}{Agent}{$_} = $agent->{$_}; }
      $kernel->yield('nextEvent',$tmp);
    }
  }
}

sub Auth {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api	  => 'auth',
			 callback => 'gotAuth',
			 method	  => 'post',
			}
			);
}

sub gotAuth {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
  my ($auth,$node,$re,$tmp);

  $self->Logmsg("got: Auth($target,",Data::Dumper->Dump([$params]),")\n");
  $auth = $obj->{PHEDEX}{AUTH};
  $self->Logmsg("Auth=,",Data::Dumper->Dump([$auth]),")\n");
  $kernel->yield('nextEvent',$payload);
}

sub Nodes {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api	  => 'nodes',
			 callback => 'gotNodes'
			}
			);
}

sub gotNodes {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
  my ($nodes,$re,$tmp);

  $self->Logmsg("got: Nodes($target,{})\n");
  $nodes = $obj->{PHEDEX}{NODE};
  $re = $payload->{workflow}{NodeFilter};
  foreach (@{$nodes}) {
    next if ( $re && !($_->{NAME} =~ m%$re%) );
    $tmp = clone $payload;
    $tmp->{workflow}{Node} = $_->{NAME};
    $kernel->yield('nextEvent',$tmp);
  }
}

sub Inject {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($params,$workflow);
  $workflow = $payload->{workflow};

#  $self->Logmsg("Inject $ds->{Name}($block->{block}, $n files) at $ds->{InjectionSite}") unless $self->{Quiet};
#  return if $self->{Dummy};
  $self->Dbgmsg("Injecting: ",Data::Dumper->Dump([$workflow]));

  $workflow->{XML} = $self->makeXML($workflow->{data});
  $params = {
	node	=> $workflow->{InjectionSite},
	strict	=> $workflow->{StrictInjection} || 0,
	data	=> $workflow->{XML},
  };
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api	  => 'inject',
			 method   => 'post',
			 callback => 'doneInject',
			 params   => $params,
			}
			);
}

sub doneInject {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];

  delete $payload->{workflow}{XML};
  my $p = $obj->{PHEDEX}{INJECTED}{STATS};
  if ( $p ) {
    $self->Logmsg("Injection: New data: $p->{NEW_DATASETS} datasets, $p->{NEW_BLOCKS} blocks, $p->{NEW_FILES} files. Closed: $p->{CLOSED_DATASETS} datasets, $p->{CLOSED_BLOCKS} blocks");
  } else {
    $self->Fatal("Injected: cannot understand output: ",Dumper($obj));
  }
  $kernel->yield('nextEvent',$payload);
}

sub T1Subscribe {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  $self->Subscribe('T1',$kernel,$session,$payload);
}

sub T2Subscribe {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  $self->Subscribe('T2',$kernel,$session,$payload);
}

sub Subscribe {
  my ($self, $type, $kernel, $session, $payload) = @_;
  my ($params,$workflow,%map);
  $workflow = $payload->{workflow};

#  $self->Fatal("No ${type}s defined for \"$workflow->{Name}\"")
#  unless defined $workflow->{$type . 's'};
  %map = (
	node	  => 'Nodes',
	data	  => 'data',
        group	  => 'Group',
        priority  => 'Priority',
        move	  => 'IsMove',
        custodial => 'IsCustodial',
  );
  foreach ( keys %map ) {
    $params->{$_} = $workflow->{$type.'Subscribe'}{$map{$_}} ||
		     $workflow->{$map{$_}};
    $self->Fatal("No $map{$_} defined for $type in \"$workflow->{Name}\"")
	 unless $params->{$_};
  }
  $params->{data} = $self->makeXML($workflow->{data});
  $self->Dbgmsg("Subscribing: ",Data::Dumper->Dump([$params]));
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api      => 'subscribe',
			 method   => 'post',
			 callback => 'doneSubscribe',
			 params   => $params,
			}
			);
}

sub doneSubscribe {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];

  my $p = $obj->{PHEDEX}{REQUEST_CREATED};
  if ( $p ) {
    foreach ( @{$p} ) {
      $self->Logmsg("$payload->{workflow}{Event}: New request: $_->{ID}");
    }
  } else {
    $self->Fatal("Injected: cannot understand output: ",Dumper($obj));
  }
  $kernel->yield('nextEvent',$payload);
}

sub Template {
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  $self->getFromDatasvc($kernel,
			$session,
			$payload,
			{
			 api	  => 'inject',
			 method   => 'post',
			 callback => 'doneTemplate'
			}
			);
}

sub doneTemplate {
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];

  $self->Logmsg("done: Template($target,",Data::Dumper->Dump([$params]),"\n");
  $kernel->yield('nextEvent',$payload);
}

1;
