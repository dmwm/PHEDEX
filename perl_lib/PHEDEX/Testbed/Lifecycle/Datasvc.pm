package PHEDEX::Testbed::Lifecycle::Datasvc;
use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
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

our $me;

sub new
{
  return $me if $me; # I am idempotent!
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { parent => shift };
  my $workflow = shift;

  my $package;
  $self->{ME} = $package = __PACKAGE__;
  $package =~ s%^$workflow->{Namespace}::%%;

  my $p = $workflow->{$package};
  map { $self->{params}{uc $_} = $params{$_} } keys %params;
  map { $self->{params}{uc $_} = $p->{$_} } keys %{$p};
  map { $self->{$_} = $p->{$_} } keys %{$p};
  $self->{UA} = PHEDEX::CLI::UserAgent->new( %{$self->{params}} );
  $self->{_njobs} = 0;
  $self->{QUEUE} = POE::Queue::Array->new();

  $self->{Verbose} = $self->{parent}->{Verbose};
  $self->{Debug}   = $self->{parent}->{Debug};
  bless $self, $class;

  POE::Session->create(
    object_states => [
      $self => {
        _start          => '_start',
        on_child_stdout => 'on_child_stdout',
        on_child_stderr => 'on_child_stderr',
        on_child_close  => 'on_child_close',
        on_child_signal => 'on_child_signal',
        start_task	=> 'start_task',
      },
    ]
  );
  $me = $self;
  return $self;
}

sub Dbgmsg { my $self = shift; $self->SUPER::Dbgmsg(@_) if $self->{Debug}; }

sub _start {
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];
  $kernel->alias_set($self->{ME});
  $self->{SESSION} = $session;
}

use POSIX;
sub slow {
  my $i = 3;
  while ( $i-- ) { print "slow... $i\n"; sleep 1; }
  POSIX::_exit(3);
}

sub start_task {
  my ($self,$heap,$kernel,$job) = @_[ OBJECT, HEAP, KERNEL, ARG0 ];
  my ($payload,$workflow,$method,$target,$params,$callback,$priority,$q_id);

  if ( $self->{_njobs} >= $self->{parent}{NJobs} ) {
    $self->Dbgmsg("enqueued $job->{method}($job->{target},",Data::Dumper->Dump([$job->{params}]),")\n");
    $self->{QUEUE}->enqueue(1,$job);
    return;
  }

  if ( ! $job ) {
    ($priority,$q_id,$job) = $self->{QUEUE}->dequeue_next();
    return unless $job;
  }
  $self->{_njobs}++;
  $payload  = $job->{payload};
  $workflow = $payload->{workflow};
  $method   = $job->{method};
  $target   = $job->{target};
  $params   = $job->{params};
  $callback = $job->{callback};

  $self->Dbgmsg("$method($target,",Data::Dumper->Dump([$params]),")\n");
  my $child = POE::Wheel::Run->new(
    Program => sub {
      my $ua = $self->{UA};
      my $response = $ua->$method($target,$params);
      my $content = $response->content();
      if ( $ua->response_ok($response) ) {
        print $content;
      } else {
        chomp $content;
        print "Bad response from server ",$response->code(),"(",$response->message(),"):\n$content\n";
        exit $response->code();
      }
    }, # TODO not thread-safe!
    StdoutEvent  => "on_child_stdout",
    StderrEvent  => "on_child_stderr",
    CloseEvent   => "on_child_close",
  );

  $kernel->sig_child($child->PID, "on_child_signal");
  $heap->{children_by_wid}{$child->ID} = $child;
  $heap->{children_by_pid}{$child->PID} = $child;
  $heap->{state}{$child->PID} = {
			 callback => $callback,
			 target   => $target,
			 params   => $params,
			 payload  => clone $payload,
			};

  $self->Dbgmsg("Child pid ",$child->PID," started as wheel ",$child->ID,".\n");
};

sub on_child_stdout {
  my ($heap,$stdout_line,$wheel_id) = @_[HEAP, ARG0, ARG1];
  my $child = $heap->{children_by_wid}{$wheel_id};
  $heap->{state}{$child->PID}{stdout} .= $stdout_line;
}

sub on_child_stderr {
  my ($heap,$stderr_line,$wheel_id) = @_[HEAP, ARG0, ARG1];
  my $child = $_[HEAP]{children_by_wid}{$wheel_id};
  $heap->{state}{$child->PID}{stderr} .= $stderr_line;
}

sub on_child_close {
  my ($self,$wheel_id) = @_[ OBJECT, ARG0 ];
  my $child = delete $_[HEAP]{children_by_wid}{$wheel_id};

  unless (defined $child) {
    $self->Dbgmsg("wid $wheel_id closed all pipes.\n");
    return;
  }

  $self->Dbgmsg("pid ",$child->PID," closed all pipes.\n");
  delete $_[HEAP]{children_by_pid}{$child->PID};
}

sub on_child_signal {
  my($self,$kernel,$heap,$sig,$pid,$rc) = @_[ OBJECT, KERNEL, HEAP, ARG0, ARG1, ARG2 ];
  my ($child,$status,$signal,$event,$callback,$target,$params,$obj);
  my ($payload,$workflow,$p,$stdout,$stderr);

  $child = delete $_[HEAP]{children_by_pid}{$_[ARG1]};

  delete $_[HEAP]{children_by_wid}{$child->ID} if defined $child;

  $status = $rc >> 8;
  $signal = $rc & 127;
  $self->Dbgmsg("pid $pid exited with status=$status, signal=$signal\n");
  $p = $heap->{state}{$pid};
  $stdout   = $p->{stdout} || '';
  $stderr   = $p->{stderr} || '';
  $payload  = $p->{payload};
  $callback = $p->{callback};
  $target   = $p->{target};
  $params   = $p->{params};
  $workflow = $payload->{workflow};
  $event    = $workflow->{Event};
  delete $heap->{state}{$pid};

  if ( $status ) {
    $obj = {
      error  => $status,
      stdout => $stdout,
      stderr => $stderr,
    };
    $self->Alert("target=$target params=",Dumper($params)," event=$event, status=$status, stdout=\"$stdout\", stderr=\"$stderr\"");
  } else {
    if ( $stdout ) {
      eval {
        no strict 'vars';
        $obj = eval($stdout);
      };
      die "Error evaluating $stdout\n" if $@;
    } else {
      $self->Logmsg("No output for event=$event");
      $obj = { stderr => $stderr, };
    }
    $kernel->post($self->{PARENT_SESSION},$callback,$payload,$obj,$target,$params);
  }

  $self->{_njobs}--;
  if ( $self->{_njobs} < $self->{parent}{NJobs} ) {
    $kernel->yield('start_task');
  }
}

sub getFromDatasvc
{
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
  $kernel->post($self->{ME},'start_task',{
				  payload	=> $payload,
				  method	=> $method,
				  target	=> $target,
				  params	=> $params,
				  callback	=> $callback,
				});
}

sub Agents
{
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

sub gotAgents
{
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

sub Auth
{
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

sub gotAuth
{
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];
  my ($auth,$node,$re,$tmp);

  $self->Logmsg("got: Auth($target,",Data::Dumper->Dump([$params]),")\n");
  $auth = $obj->{PHEDEX}{AUTH};
  $self->Logmsg("Auth=,",Data::Dumper->Dump([$auth]),")\n");
  $kernel->yield('nextEvent',$payload);
}

sub Nodes
{
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

sub gotNodes
{
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

sub Inject
{
  my ($self, $kernel, $session, $payload) = @_[ OBJECT, KERNEL, SESSION, ARG0 ];
  my ($params,$workflow);
  $workflow = $payload->{workflow};

#  $self->Logmsg("Inject $ds->{Name}($block->{block}, $n files) at $ds->{InjectionSite}") unless $self->{Quiet};
#  return if $self->{Dummy};
  $self->Dbgmsg("Injecting: ",Data::Dumper->Dump([$workflow]));

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

sub doneInject
{
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];

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

sub Subscribe
{
  my ($self, $type, $kernel, $session, $payload) = @_;
  my ($params,$workflow,%map);
  $workflow = $payload->{workflow};

#  $self->Fatal("No ${type}s defined for \"$workflow->{Name}\"")
#  unless defined $workflow->{$type . 's'};
  %map = (
	node	  => 'Nodes',
	data	  => 'XML',
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

sub doneSubscribe
{
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

sub Template
{
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

sub doneTemplate
{
  my ($self,$kernel,$payload,$obj,$target,$params) = @_[ OBJECT, KERNEL, ARG0, ARG1, ARG2, ARG3 ];

  $self->Logmsg("done: Template($target,",Data::Dumper->Dump([$params]),"\n");
  $kernel->yield('nextEvent',$payload);
}

1;
