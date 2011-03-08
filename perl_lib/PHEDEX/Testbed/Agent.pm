package PHEDEX::Testbed::Agent;

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::Testbed::SQL', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;
use POE;
use Data::Dumper;

our %params =
	(
	  WAITTIME		=> 0,
	  VERBOSE		=> $ENV{PHEDEX_VERBOSE} || 0,
	  DEBUG			=> $ENV{PHEDEX_DEBUG} || 0,
	  ME			=> 'TestbedAgent',
	  ConfigRefresh		=> 3,
	);

our @array_params = qw / /;
our @hash_params  = qw / /;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(%params,@_);
  bless $self, $class;

  my $sender_args = $self->{SENDER_ARGS};
  if ( $sender_args )
  {
    my $sender = T0::Logger::Sender->new( %{$sender_args} );
    $self->{SENDER} = $sender;
  }

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

sub init
{
  my $self = shift;

# base initialisation
  $self->SUPER::init(@_);

# Now my own specific values...
  $self->SUPER::init
	(
	  ARRAYS => [ @array_params ],
	  HASHES => [ @hash_params ],
	);
}

sub idle { }
sub isInvalid { return 0; }
sub stop { }
sub processDrop { }
sub process { }

sub OnConnect
{
  my ( $self, $heap, $kernel ) = @_[ OBJECT, HEAP, KERNEL ];

# Only start the timer first time round, or there will be one timer per time
# the receiver is restarted
  return 0 if $heap->{count};
  print "OnConnect: self=$self, heap=$heap\n";

  return 0;
}

sub Log
{
  my $self = shift;
  my $sender = $self->{SENDER};
  if ( $sender ) { $sender->Send(@_); }
  else
  {
    $Data::Dumper::Terse=1;
    $Data::Dumper::Indent=0;
    my $a = Data::Dumper->Dump([\@_]);
    $a =~ s%\n%%g;
    $a =~ s%\s\s+% %g;
    $self->Logmsg($a);
  }
}

1;
