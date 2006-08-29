use strict;
package T0::StorageManager::Worker;
use POE;
use POE::Filter::Reference;
use POE::Component::Client::TCP;
use POE::Wheel::Run;
use Sys::Hostname;
use T0::Util;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);

use Carp;
$VERSION = 1.00;
@ISA = qw/ Exporter /;

$StorageManager::Name = 'SM::Worker-' . hostname();

my ($i,@queue);
our $hdr = __PACKAGE__ . ':: ';
sub Croak   { croak $hdr,@_; }
sub Carp    { carp  $hdr,@_; }
sub Verbose { T0::Util::Verbose( (shift)->{Verbose}, @_ ); }
sub Debug   { T0::Util::Debug(   (shift)->{Debug},   @_ ); }
sub Quiet   { T0::Util::Quiet(   (shift)->{Quiet},   @_ ); }

sub _init
{
  my $self = shift;

  $self->{Name} = $StorageManager::Name . '-' . $$;
  my %h = @_;
  map { $self->{$_} = $h{$_}; } keys %h;
  $self->ReadConfig();
  $self->{Host} = hostname();
  $ENV{STAGE_SVCCLASS} = $self->{SvcClass} || 't0input';

  if ( defined($self->{Logger}) ) { $self->{Logger}->Name($self->{Name}); }

  POE::Component::Client::TCP->new
  ( RemotePort     => $self->{Manager}->{Port},
    RemoteAddress  => $self->{Manager}->{Host},
    Alias          => $self->{Name},
    Filter         => "POE::Filter::Reference",
    Connected      => \&_connected,
    ServerInput    => \&_server_input,
    InlineStates   => {
      got_child_stdout	=> \&got_child_stdout,
      got_child_stderr	=> \&got_child_stderr,
      got_child_close	=> \&got_child_close,
      got_sigchld	=> \&got_sigchld,
    },
    Args => [ $self ],
    ObjectStates   => [
	$self =>	[
				server_input => 'server_input',
				connected => 'connected',
      				job_done => 'job_done',
      				get_work => 'get_work',
			]
	],
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

our @attrs = ( qw/ Name Host ConfigRefresh Config / );
our %ok_field;
for my $attr ( @attrs ) { $ok_field{$attr}++; }

sub AUTOLOAD {
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  Croak "AUTOLOAD: Invalid attribute method: ->$attr()" unless $ok_field{$attr};
  $self->{$attr} = shift if @_;
# if ( @_ ) { Croak "Setting attributes not yet supported!\n"; }
  return $self->{$attr};
}

sub ReadConfig
{
  my $self = shift;
  my $file = $self->{Config};

  return unless $file;
  $self->Log("Reading configuration file ",$file);

  $self->{Partners} = { Manager => 'StorageManager::Manager' };
  T0::Util::ReadConfig( $self, , 'StorageManager::Worker' );

  $self->{Interval} = $self->{Interval} || 10;
}

sub Log
{ 
  my $self = shift;
  my $logger = $self->{Logger}; 
  defined $logger && $logger->Send(@_);
}

sub got_child_stdout {
  my ($self,$stdout) = @_[ OBJECT, ARG0 ];
# $self->Quiet("STDOUT: $stdout\n");
}

sub got_child_stderr {
  my ($self,$stderr) = @_[ OBJECT, ARG0 ];
  $stderr =~ tr[ -~][]cd;
  Print "STDERR: $stderr\n";
}

sub got_child_close {
  my ( $self, $kernel, $heap ) = @_[ OBJECT, KERNEL, HEAP ];
# if ( $self->{Debug} )
# {
#   my $work = $heap->{program}[$heap->{program}->PROGRAM];
#   Print "child closed: $work, ",$heap->{Work}->{$work},"\n";
# }
}

sub got_sigchld
{
  my ( $self, $heap, $kernel, $child_pid, $status ) =
			@_[ OBJECT, HEAP, KERNEL, ARG1, ARG2 ];
  my $work = $heap->{program}[$heap->{program}->PROGRAM];
# $self->Debug("sig_chld handler: PID=$child_pid, RC=$status Prog=$work\n");
  $kernel->yield( 'job_done', [ work => $work, status => $status ] );
  if ( $child_pid == $heap->{program}->PID ) {
    delete $heap->{program};
    delete $heap->{stdio};
  }
  return 0;
}

sub _server_input { reroute_event( (caller(0))[3], @_ ); }
sub server_input {
  my ( $self, $kernel, $heap, $input ) = @_[ OBJECT, KERNEL, HEAP, ARG0 ];
  my ( $command, $client, $setup, $work, $priority, $interval, $size, $target );

  $command  = $input->{command};
  $client   = $input->{client};

  $self->Verbose("from server: $command\n");
  if ( $command =~ m%DoThis% )
  {
    $work     = $input->{work};
    $priority = $input->{priority};
    $priority = 99 unless defined($priority);
    $interval = $input->{interval};
    $size     = $input->{size};
    $target   = $input->{target};

    $target && $self->Log("$command: target=$target priority=$priority interval=$interval size=$size");
    $self->Quiet("Got $command($work,$priority)...\n");
    $heap->{Work}->{$work}->{Priority} = $priority;
    $heap->{Work}->{$work}->{Interval} = $interval;
    $heap->{Work}->{$work}->{Size}     = $size;
    $heap->{Work}->{$work}->{Target}   = $target;
    $heap->{program} = POE::Wheel::Run->new
      ( Program	     => $work,
        StdioFilter  => POE::Filter::Line->new(),
        StderrFilter => POE::Filter::Line->new(),
        StdoutEvent  => "got_child_stdout",
        StderrEvent  => "got_child_stderr",
        CloseEvent   => "got_child_close",
      );
    $kernel->sig( CHLD => "got_sigchld" );

    return;
  }

  if ( $command =~ m%Setup% )
  {
    $self->Quiet("Got $command...\n");
    $setup = $input->{setup};
    $self->{Debug} && dump_ref($setup);
    map { $self->{$_} = $setup->{$_} } keys %$setup;
    $kernel->yield('get_work');
    return;
  }

  if ( $command =~ m%Start% )
  {
    $self->Quiet("Got $command...\n");
    $kernel->yield('get_work');
    return;
  }

  if ( $command =~ m%Quit% )
  {
    $self->Quiet("Got $command...\n");
    $kernel->yield('shutdown');
    return;
  }

  Print "Error: unrecognised input from server! \"$command\"\n";
  $kernel->yield('shutdown');
}

sub _connected { reroute_event( (caller(0))[3], @_ ); }
sub connected
{
  my ( $self, $heap, $kernel, $input ) = @_[ OBJECT, HEAP, KERNEL, ARG0 ];
  $self->Debug("handle_connect: from server: $input\n");
  my %text = (  'command'       => 'HelloFrom',
                'client'        => $self->{Name},
             );
  $heap->{server}->put( \%text );
}

sub get_work
{
  my ( $self, $heap, $kernel ) = @_[ OBJECT, HEAP, KERNEL ];

  if ( ! defined($heap->{server}) )
  {
    $self->Verbose("No server! Wait a while...\n");
    $kernel->delay_set( 'get_work', 3 );
  }

  $self->Debug("Tasks remaining: ",$self->{MaxTasks},"\n");
  if ( $self->{MaxTasks}-- > 0 )
  {
    my %text = ( 'command'      => 'SendWork',
                 'client'       => $self->{Name},
                );
    $heap->{server}->put( \%text );
  }
}

sub client_input {
  my ( $heap, $input ) = @_[ HEAP, ARG0 ];
  Print "client_input: from server: $input\n";
  Croak "Do I ever get here...?\n";
}

sub job_done
{
  my ( $self, $heap, $kernel, $arg0 ) = @_[ OBJECT, HEAP, KERNEL, ARG0 ];
  my %h = @{ $arg0 };

  $h{priority} = $heap->{Work}->{$h{work}}->{Priority};
  $h{interval} = $heap->{Work}->{$h{work}}->{Interval};
  $h{size}     = $heap->{Work}->{$h{work}}->{Size};
  $h{target}   = $heap->{Work}->{$h{work}}->{Target};

  $self->Quiet("Send: JobDone: work=$h{work}, status=$h{status}, priority=$h{priority} interval=$h{interval}\n");
  $h{priority} && $self->Log("JobDone: target=$h{target} status=$h{status} priority=$h{priority} interval=$h{interval} size=$h{size}");
  $h{priority} && $self->Log(\%h);
  if ( defined($heap->{server}) )
  {
    delete $heap->{Work}->{$h{work}};
    $h{command} = 'JobDone';
    $h{client}  = $self->{Name};
    $heap->{server}->put( \%h );
  }
  else
  {
    Print "Woah, server left me! Couldn't send ",join(', ',%h),"\n";
  }

  my $w = scalar(keys %{$heap->{Work}});
  $self->Verbose("JobDone: tasks left=",$self->{MaxTasks}," queued=$w\n");

# priority-zero tasks don't count against my total!
  if ( !$h{priority} ) { $self->{MaxTasks}++; }

  if ( $self->{MaxTasks} > 0 )
  {
#   If I had a priority-zero task, or my interval is zero, go back for
#   another task straight away, otherwise wait...
    if ( $h{priority} && $h{interval} )
    {
      $kernel->delay( 'get_work', $h{interval} );
    }
    else
    {
      $kernel->yield( 'get_work' );
    }
  }

  if ( $self->{MaxTasks} <= 0 && ! $w )
  {
    Print "Shutting down...\n";
    $kernel->yield('shutdown');
  }
}

1;
