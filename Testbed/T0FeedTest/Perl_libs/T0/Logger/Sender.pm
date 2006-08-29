use strict;
package T0::Logger::Sender;
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

$Logger::Name = 'Logger::Sender';

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

  $self->{Name} = $Logger::Name . '-' . hostname() . '-' . $$;
  my %h = @_;
  map { $self->{$_} = $h{$_}; } keys %h;
  $self->ReadConfig();
  $self->{Host} = hostname();

  defined($self->{Receiver}->{Port}) &&
  defined($self->{Receiver}->{Host}) ||
    Croak "Host or Port not defined in Receiver hash\n";

  foreach ( qw / OnConnect OnError / )
  {
    $self->{$_} = sub { return 0; } unless defined $self->{$_};
  }

  POE::Component::Client::TCP->new
  ( RemotePort     => $self->{Receiver}->{Port},
    RemoteAddress  => $self->{Receiver}->{Host},
    Alias          => $self->{Name},
    Filter         => "POE::Filter::Reference",
    ServerError    => \&server_error,
    ConnectError   => \&_connection_error_handler,
    Disconnected   => \&_connection_error_handler,
    Connected      => \&_connected,
    ServerInput    => \&_server_input,
#    Started	   => \&started,
    ObjectStates   => [
	$self => [
			    server_input => 'server_input',
			       connected => 'connected',
		connection_error_handler => 'connection_error_handler',
				    send => 'send',
		 ],
	],
    Args => [ $self ],
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
  T0::Util::ReadConfig($self);
  map { $self->{Receiver}->{$_} = $Logger::Receiver{$_}
	unless $self->{Receiver}->{$_} } keys %Logger::Receiver;
}

sub Send
{
  my $self = shift;
  my $ref = $_[0];

# This is a mess, I should learn how to tidy it up before anyone sees it!
  if ( $self->{Session} )
  {
    if ( scalar @_ == 1 )
    {
      if ( ref($ref) )
      { $poe_kernel->post( $self->{Session} , 'send', $ref ); }
      else
      { $poe_kernel->post( $self->{Session} , 'send', \$ref ); }
    }
    else
    { $poe_kernel->post( $self->{Session} , 'send', \@_ ); }
    return;
  }

  return unless $self->{QueueEntries};

  if ( scalar @_ == 1 )
  {
    if ( ref($ref) )
    { push @{$self->{Queue}}, $ref; }
    else
    { push @{$self->{Queue}}, \$ref; }
  }
  else
  { push @{$self->{Queue}}, \@_; }
}

sub error        { Print $hdr," error\n"; }
sub server_error { Print $hdr," Server error\n"; }

sub _connection_error_handler { reroute_event( (caller(0))[3], @_ ); }
sub connection_error_handler
{
  my ( $self, $kernel ) = @_[ OBJECT, KERNEL ];

  return if $self->{OnError}(@_);

  my $retry = $self->{RetryInterval};
  defined($retry) && $retry>0 || return;

  if ( !$self->{Retries}++ )
  {
    Print $hdr," Connection retry every $retry seconds\n";
  }
  $kernel->delay( reconnect => $retry );
}

sub _server_input { reroute_event( (caller(0))[3], @_ ); }
sub server_input {
  my ( $self, $input ) = @_[ OBJECT, ARG0 ];
  my ( $text, $client );

  $text   = $input->{text};
  $client = $input->{client};

  $self->Debug("from server: $text\n");
}

sub FlushQueue
{
  my $self = shift;
  my $heap = shift;
  while ( $_ = shift @{$self->{Queue}} )
  {
    $self->Debug("Draining queue: ",$_,"\n");
    $heap->{server}->put($_);
  }
}

sub _connected { reroute_event( (caller(0))[3], @_ ); }
sub connected
{
  my ( $self, $heap, $session, $input ) = @_[ OBJECT, HEAP, SESSION, ARG0 ];

  $self->{Session} = $session->ID;
  $self->{Retries} = 0;

  $self->Debug("handle_connect: from server: $input\n");
  my %text = (  'text'   => 'I live...',
                'client' => $self->{Name},
             );
  $heap->{server}->put( \%text );
  Print $hdr," Connection established (",$session->ID,")\n";

  return if $self->{OnConnect}(@_);

  $self->FlushQueue($heap);
}

sub send
{
  my ( $self, $heap, $ref ) = @_[ OBJECT, HEAP, ARG0 ];
  if ( !ref($ref) ) { $ref = \$ref; }
  if ( $heap->{connected} && $heap->{server} )
  {
    $self->FlushQueue($heap);
    $heap->{server}->put( $ref );
  }
  else
  {
    return unless $self->{QueueEntries};
    push @{$self->{Queue}}, $ref;
  }
}

1;
