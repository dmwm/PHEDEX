package PHEDEX::Core::Logging;

=head1 NAME

PHEDEX::Core::Logging - a drop-in replacement for Toolkit/UtilsLogging

Although this module will be replaced by the Log4Perl module at some point,
it's still included here for completeness.

The logmsg() function has been changed to call 'warn()' directly, rather than
simply print to STDERR, while the note() function prints to STDERR, but does
not do it via the logmsg function anymore. The practical result of this is
that if you are using the PHEDEX::Debug module to debug your script, any call
to the logmsg(), warn() or alert() functions in this package will cause the
program to abort.

fatal() calls exit(1) after it prints a message to the log.

=cut

use strict;
use warnings;
use base 'Exporter';
our @EXPORT = qw( Hdr ); # logmsg alert      dbgmsg fatal note);
use POSIX;

# 'new' is declared as a dummy routine, just in case it ever gets called...
sub new {}

# As a demonstration, prepare to throw out UDP messages if required.
BEGIN
{
  if ( defined($ENV{PHEDEX_NOTIFICATION_PORT}) )
  {
    eval("use IO::Socket");
    if ( $@ ) { undef $ENV{PHEDEX_NOTIFICATION_PORT}; }
  };
}

sub Logmsg
{   
  my $self = shift;
  print PHEDEX::Core::Logging::Hdr($self),@_,"\n";
}

sub Notify
{
  my $self = shift;
  my $port = $self->{NOTIFICATION_PORT} || $ENV{PHEDEX_NOTIFICATION_PORT};
  return unless defined $port;
  my $server = $self->{NOTIFICATION_HOST} || $ENV{PHEDEX_NOTIFICATION_HOST} || '127.0.0.1';

  my $message = join('',$self->Hdr,@_);
  my $socket = IO::Socket::INET->new( Proto	=> 'udp',
				      PeerPort	=> $port,
				      PeerAddr	=> $server );
  $socket->send( $message );
}

sub Alert
{   
  my $self = shift;
  PHEDEX::Core::Logging::Logmsg ($self,"alert: ", @_);
  PHEDEX::Core::Logging::Notify ($self,"alert: ", @_,"\n");
}

sub Warn
{   
  my $self = shift;
  PHEDEX::Core::Logging::Logmsg ($self,"warning: ", @_);
  PHEDEX::Core::Logging::Notify ($self,"warning: ", @_,"\n");
}   

sub Dbgmsg
{
  my $self = shift;
  PHEDEX::Core::Logging::Logmsg ($self,"debug: ", @_);
}

sub Fatal
{
  my $self = shift;
  PHEDEX::Core::Logging::Logmsg ($self,"fatal: ", @_);
  PHEDEX::Core::Logging::Notify ($self,"fatal: ", @_,"\n");
  exit(1);
}

sub Note
{
  my $self = shift;
  print PHEDEX::Core::Logging::Hdr($self)," note: ", @_, "\n";
}

sub Hdr
{ 
  my $self = shift;
  my $me;
  if ( $self ) { $me  = $self->{ME} };
  if ( !$me ) { $me = $0; $me =~ s|.*/||; }
  my $date = strftime ("%Y-%m-%d %H:%M:%S", gmtime);
  return "$date: $me\[$$]: ";
}

1;
