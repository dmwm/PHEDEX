package PHEDEX::Testbed::Agent;

use strict;
use warnings;
use base 'PHEDEX::Core::Logging';
use PHEDEX::Core::Agent;
use PHEDEX::Core::Timing;
use POE;
use Data::Dumper;

our %params =
	(
	  VERBOSE		=> $ENV{PHEDEX_VERBOSE} || 0,
	  DEBUG			=> $ENV{PHEDEX_DEBUG} || 0,
	  ME			=> 'TestbedAgent',
	  ConfigRefresh		=> 3,
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(%params,@_);
  bless $self, $class;
  if ( $self->{DROPDIR} && $self->{LOGFILE} ) {
    $self->{PIDFILE} = $self->{DROPDIR} . 'pid';
    PHEDEX::Core::Agent::daemon($self);
  }

#   Start a POE session for myself
    POE::Session->create
      (
        object_states =>
        [
          $self =>
          {
            _preprocess         => '_preprocess',
            _process_start      => '_process_start',
            _process_stop       => '_process_stop',
            _maybeStop          => '_maybeStop',
            _make_stats         => '_make_stats',

            _start   => '_start',
            _stop    => '_stop',
            _child   => '_child',
            _default => '_default',
          },
        ],
      );

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
# $self->SUPER::init(@_);
}

sub idle { }
sub isInvalid { return 0; }
sub stop { }
sub processDrop { }
sub process { }
sub _process_start { }
sub _process_stop { }
sub _make_stats { }
sub _preprocess { }
sub _maybeStop { }

sub _start { PHEDEX::Core::Agent::_start(@_); }
sub _default {
  my $self = shift;
  if ( $self->can('poe_default') ) {
    $self->poe_default(@_);
    return;
  }
  PHEDEX::Core::Agent::_default(@_);
}

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
