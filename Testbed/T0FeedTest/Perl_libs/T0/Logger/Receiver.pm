use strict;
package T0::Logger::Receiver;
use Data::Dumper;
use POE;
use POE::Component::Server::TCP;
use POE::Filter::Reference;
use T0::Util;
use T0::FileWatcher;
use T0::Logger::Sender;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);
my $debug_me=1;

$Data::Dumper::Terse++;
use Carp;
$VERSION = 1.00;
@ISA = qw/ Exporter /;
$Logger::Name = 'Logger::Receiver';

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

  $self->{Name} = $Logger::Name;
  my %h = @_;
  map { $self->{$_} = $h{$_}; } keys %h;
  $self->ReadConfig();

  check_host( $self->{Host} );

  $self->{OnInput} = \&OnInputDefault unless defined $self->{OnInput};
  foreach ( qw / OnError OnDisconnected OnInput / )
  {
    $self->{$_} = sub { return 0; } unless defined $self->{$_};
  }

  POE::Component::Server::TCP->new
  ( Port                => $self->{Port},
    Alias               => $self->{Name},
    ClientFilter        => "POE::Filter::Reference",
    ClientInput         => \&_client_input,
    ClientDisconnected  => \&_client_disconnected,
    ClientError         => \&_client_error,
    Started             => \&started,
    ObjectStates	=> [
	$self => [ 	   FileChanged => 'FileChanged',
		   client_disconnected => 'client_disconnected',
		   	  client_error => 'client_error',
		   	  client_input => 'client_input',
			rotate_logfile => 'rotate_logfile',
		      set_rotate_alarm => 'set_rotate_alarm',
		 ],
	],
    Args => [ $self ],
  );

  if ( defined($self->{Logfile}) )
  {
    open STDOUT, ">>$self->{Logfile}" or die "open: $self->{Logfile}: $!\n";
    open(STDERR,">&STDOUT") or croak "Cannot dup STDOUT: $!\n";
  }
# Turn off STDOUT bufferring...
  select(STDOUT); $|=1;
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

our @attrs = ( qw/ Host Port Name ConfigRefresh Config / );
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

sub started
{
  my ( $self, $kernel, $heap, $session ) = @_[ ARG0, KERNEL, HEAP, SESSION ];
  $self->Verbose("Logger listener has started...\n");

  return unless $self->{Config};
  my %param = ( File     => $self->{Config},
                Interval => $self->{ConfigRefresh},
                Client   => $self->{Name},
                Event    => 'FileChanged',
              );
  $kernel->state( 'FileChanged', $self );
  $self->{Watcher} = T0::FileWatcher->new( %param );

  $kernel->state( 'rotate_logfile',   $self );
  $kernel->state( 'set_rotate_alarm', $self );
  $kernel->yield( 'set_rotate_alarm' );
}

sub FileChanged
{
  my $self = $_[ OBJECT ];
  $self->Quiet("\"",$self->{Config},"\" has changed...\n");
  $self->ReadConfig();
}

sub ReadConfig
{
  my $self = shift;
  my $file = $self->{Config};
  return unless $file;
  $self->{Partners} = { Sender => 'Logger::Sender' };
  T0::Util::ReadConfig($self);

  if ( defined($self->{Watcher}) )
  {
    $self->{Watcher}->Interval($self->{ConfigRefresh});
    $self->{Watcher}->Options( %FileWatcher::Params);
  }
}

sub _client_error { reroute_event( (caller(0))[3], @_ ); }
sub client_error
{
  my ( $self, $heap ) = @_[ OBJECT, HEAP ];

  return if $self->{OnError}(@_);

  my $client = $heap->{client_name};
  $self->Quiet($client,": client_error\n");
}

sub _client_disconnected { reroute_event( (caller(0))[3], @_ ); }
sub client_disconnected
{
  my ( $self, $kernel, $heap ) = @_[ OBJECT, KERNEL, HEAP ];

  return if $self->{OnDisconnected}(@_);

  my $client = $heap->{client_name};
  my ($h,$key,$index,$name);
  foreach $h ( @{$self->{Subscribed}{$client}} )
  {
    $key   = $h->{key};
    $index = $h->{index};
    next unless defined($self->{Filter}{$key}{$index});
    if ( $self->{Filter}{$key}{$index}{Logger}->{QueueEntries} )
    {
      $self->Quiet("Keeping configuration for key=$key, client=$client\n");
      next;
    }
    $self->Quiet("Killing configuration for key=$key, client=$client\n");
    $name = $self->{Filter}{$key}{$index}{Logger}->{Session};
    Print "Shutting down $name\n";
    $kernel->post( $name => 'shutdown' );
    delete $self->{Filter}{$key}{$index}{Logger};
    delete $self->{Filter}{$key}{$index};
  }
  $self->Quiet($client,": client_disconnected\n");
}

sub Subscribe
{
  my ($self,$client,$h) = @_;
  my ($host,$port,$key,$value,$i);
  foreach ( qw / Host Port Key / )
  { exists($h->{$_}) or Croak "\"$_\" missing from input hash\n"; }
  $host  = $h->{Host};
  $port  = $h->{Port};
  $key   = $h->{Key};
  $value = $h->{Value} || undef;

# Check for duplication...
  if ( defined($self->{Filter}{$key}) )
  {
    foreach ( $self->{Index}{$key} )
    {
      return if (
	  ( $self->{Filter}{$key}{$_}{Host}  eq $host  ) &&
	  ( $self->{Filter}{$key}{$_}{Port}  eq $port  ) &&
	  ( $self->{Filter}{$key}{$_}{Value} eq $value ) );
    }
  }
  $i = ++$self->{Index}{$key};
  $self->{Filter}{$key}{$i}{Host}   = $host;
  $self->{Filter}{$key}{$i}{Port}   = $port;
  $self->{Filter}{$key}{$i}{Value}  = $value;
  $self->{Filter}{$key}{$i}{Logger} = T0::Logger::Sender->new(
	Receiver => {	Port	=> $port,
			Host	=> $host,
		    },
	RetryInterval	=> $h->{RetryInterval} || 0,
	QueueEntries	=> $h->{QueueEntries}  || 0,
	Name		=> $client,
	);
  my %x = ( key => $key, index => $i );
  push @{$self->{Subscribed}{$client}}, \%x;
}

sub Unsubscribe
{
  my ($self,$client,$h) = @_;
  my ($host,$port,$key,$value,$i);
  foreach ( qw / Host Port Key / )
  { exists($h->{$_}) or Croak "\"$_\" missing from input hash\n"; }
  $host  = $h->{Host};
  $port  = $h->{Port};
  $key   = $h->{Key};
  $value = $h->{Value} || undef;
  foreach $i ( sort { $a <=> $b } keys %{$self->{Filter}{$key}} )
  {
    if ( $self->{Filter}{$key}{$i}{Host}  eq $host &&
         $self->{Filter}{$key}{$i}{Port}  eq $port &&
         $self->{Filter}{$key}{$i}{Value} eq $value )
    {
      Print "Found matching subscription! $i\n";
      if ( $self->{Filter}{$key}{$i}{Logger} )
      {
        Print "Setting QueueEntries to zero...\n";
        $self->{Filter}{$key}{$i}{Logger}->Options( QueueEntries => 0,
						   RetryInterval => 0);
      }
      delete $self->{Filter}{$key}{$i};
    }
  }
}

sub _client_input { reroute_event( (caller(0))[3], @_ ); }
sub client_input
{
  my ( $self, $kernel, $heap, $session, $input ) =
	 @_[ OBJECT, KERNEL, HEAP, SESSION, ARG0 ];
  my ( $date, $text, $client );


  if ( ref($input) =~ m%^HASH% )
  {
#   Special case for adding new clients...
    if ( $input->{text} =~ m%^I live...$% )
    {
      Print "new client: ",$input->{client},"\n";
      $heap->{client_name} = $input->{client};
    }
    $input->{date} = scalar localtime unless defined $input->{date};
  }

  return if $self->{OnInput}(@_);

  if ( ref($input) =~ m%^HASH% )
  {
#   First, look for MonaLisa events, and post them...
    if ( defined( $input->{MonaLisa} ) )
    {
      if ( defined($self->{ApMon}) )
      {
        $self->{ApMon}->Send($input);
      }
    }
#      my $cluster = $input->{Cluster};
#      my $farm    = $input->{Farm};
#      foreach ( qw / MonaLisa Cluster Farm / ) { delete $input->{$_}; }
#      $apm->sendParameters( $cluster, $farm, %$input );
#      $input->{Cluster} = $cluster; $input->{Farm} = $farm;
#      $input->{MonaLisa}++;
#    }

#   Look for subscribtions matching this hash...
    my ($k,$i,$v);
    foreach $k ( keys %{$self->{Filter}} )
    {
      next unless exists($input->{$k});

      my $g = $self->{Filter}{$k};
      foreach $i ( keys %{$g} )
      {
        $self->Debug("$i : ",join(' ',%{$g->{$i}}),"\n");
        if ( $input->{$k} =~ m%^$g->{$i}->{Value}$% )
        {
          $self->Debug(" Value matches!\n");
          $self->{Filter}{$k}{$i}{Logger}->Send($input);
        }
      }
    }

#   Look for 'RPC's, i.e. Subscribe/Unsubscribe notifications...
    my $RPC = $input->{RPC};
    if ( $RPC && $self->can($RPC) )
    {
      Print "Got a \"$RPC\" event...\n";
      eval { $self->$RPC( $heap->{client_name}, $input); };
      if ( $@ ) { Carp $@,"\n"; }
    }
  }
}

sub set_rotate_alarm
{
  my $kernel = $_[ KERNEL ];
  my @n = localtime;
  my $wakeme = time + 86400 - $n[0] - 60*$n[1] - 3600*$n[2];
  print "Set alarm for ", scalar localtime $wakeme, "\n";
  $kernel->alarm_set( rotate_logfile => $wakeme );
}

sub rotate_logfile
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];
  return unless defined($self->{Logfile});
  my $now = T0::Util::timestamp;
  close STDOUT;
  rename $self->{Logfile}, $self->{Logfile} . '.' . $now || 
    Croak "Cannot rename $self->{Logfile}: $!\n";
  open STDOUT, ">>$self->{Logfile}" or Croak "open $self->{Logfile}: $!\n";
# open(STDERR,">&STDOUT") or Croak "Cannot dup STDOUT: $!\n";
  select(STDOUT); $|=1;
  $kernel->yield('set_rotate_alarm');
}

sub OnInputDefault
{
# This naive default will dump the contents of the input hash
  my ( $self, $kernel, $heap, $session, $input ) =
	 @_[ OBJECT, KERNEL, HEAP, SESSION, ARG0 ];

  if ( ref($input) =~ m%^HASH% )
  {
    foreach ( qw / date client / )
    {
      if ( defined($input->{$_}) )
      {
        print $input->{$_},': ';
        delete $input->{$_};
      }
    }
  }

  if ( ref($input) =~ m%^SCALAR% )
  {
    Print ${$input};
  }
  else
  {
    my $a = Data::Dumper->Dump([$input]);
    $a =~ s%\n%%g;
    $a =~ s%\s\s+% %g;
    print $a;
  }
  print "\n";
  return 0;
}

1;
