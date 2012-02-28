package PHEDEX::Testbed::Lifecycle::Datasvc;
use strict;
use warnings;
use POE qw( Queue::Array );
use Clone qw(clone);
use Data::Dumper;
use PHEDEX::CLI::UserAgent;

our %params = (
	  cert_file => $ENV{HOME} . '/.globus/usercert.pem',
	  key_file  => $ENV{HOME} . '/.globus/userkey.pem',
	  url       => 'https://cmsweb.cern.ch/phedex/datasvc',
	  instance  => 'prod',
	  format    => 'perl',
	  timeout   => 60,
	  proxy     => undef,
	  ca_file   => undef,
	  ca_dir    => undef,
	  nocert    => undef,
	);

our $me;

sub new
{
  return $me if $me; # I am idempotent!
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { parent => shift };

  my $package = __PACKAGE__;
  $self->{ME} = $package;

  my $p = $self->{parent}{$package};
  map { $self->{params}{uc $_} = $params{$_} } keys %params;
  map { $self->{params}{uc $_} = $p->{$_} } keys %{$p};
  map { $self->{$_} = $p->{$_} } keys %{$p};
  $self->{UA} = PHEDEX::CLI::UserAgent->new( %{$self->{params}} );
  $self->{_njobs} = 0;
  $self->{QUEUE} = POE::Queue::Array->new();
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

sub Logmsg { (shift)->{parent}->Logmsg(@_); }

sub Verbose
{
  my $self = shift;
  return unless $self->{parent}->{Verbose};
  $self->{parent}->Logmsg(@_);
}

sub Dbgmsg
{
  my $self = shift;
  return unless $self->{parent}->{Debug};
  $self->{parent}->Dbgmsg(@_);
}

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
  my ($payload,$method,$target,$params,$callback,$priority,$q_id);

  if ( $self->{_njobs} >= $self->{NJobs} ) {
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
  $heap->{state}{$child->PID}{sterr} .= $stderr_line;
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
  my ($child,$status,$signal,$output,$event,$callback,$target,$params,$obj,$payload);

  $child = delete $_[HEAP]{children_by_pid}{$_[ARG1]};

  delete $_[HEAP]{children_by_wid}{$child->ID} if defined $child;

  $status = $rc >> 8;
  $signal = $rc & 127;
  $self->Dbgmsg("pid $pid exited with status=$status, signal=$signal\n");
  $output   = $heap->{state}{$pid}{stdout};
  $event    = $heap->{state}{$pid}{event};
  $callback = $heap->{state}{$pid}{callback};
  $target   = $heap->{state}{$pid}{target};
  $params   = $heap->{state}{$pid}{params};
  $payload  = $heap->{state}{$pid}{payload};
  delete $heap->{state}{$pid};
  eval {
    no strict 'vars';
    $obj = eval($output);
  };
  die "Error evaluating $output\n" if $@;
  $kernel->post($self->{PARENT_SESSION},$callback,$payload,$obj,$target,$params);

  $self->{_njobs}--;
  if ( $self->{_njobs} < $self->{NJobs} ) {
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
  $self->Logmsg("$method($target,",
		 join(', ',map { "$_=$params->{$_}" } sort keys %{$params}),
		 ")\n");
  $kernel->post($self->{ME},'start_task',{
				  payload	=> $payload,
				  method	=> $method,
				  target	=> $target,
				  params	=> $params,
				  callback	=> $callback,
				});
}

sub getNodes
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

sub getAgents
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

sub getAuth
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
#  foreach $agent (@{$agents}) {
#    next if ( $agent->{AGENT}[0]{LABEL} =~ m%^mgmt-%  && $agent->{NODE} ne 'T0_CH_CERN_Export' );
#    foreach ( @{$agent->{AGENT}} ) {
#      $tmp = clone $payload;
#      $tmp->{workflow}{Agent} = $_;
#      foreach ( qw/ HOST NAME NODE / ) { $tmp->{workflow}{Agent}{$_} = $agent->{$_}; }
#      $kernel->yield('nextEvent',$tmp);
#    }
#  }
   $kernel->yield('nextEvent',$payload);
}
1;
