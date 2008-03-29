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

## Produce an alert message
#sub logmsg
#{
#    my $date = strftime ("%Y-%m-%d %H:%M:%S", gmtime);
#    my $me = $0; $me =~ s|.*/||;
#    warn         "$date: ${me}\[$$]: ", @_, "\n";
#}
#
#sub alert
#{
#    &logmsg ("alert: ", @_);
#}
#
##sub warn
##{
##    &logmsg ("warning: ", @_);
##}
#
#sub dbgmsg
#{
#    &logmsg ("debug: ", @_);
#}
#
#sub fatal
#{
#    &logmsg ("fatal: ", @_);
#    exit(1);
#}
#
#sub note
#{
#    my $date = strftime ("%Y-%m-%d %H:%M:%S", gmtime);
#    my $me = $0; $me =~ s|.*/||;
#    print STDERR "$date: ${me}\[$$]: note: ", @_, "\n";
#}

# As a demonstration, prepare to throw out UDP messages if required...
BEGIN
{
  if ( defined($ENV{PHEDEX_UDP_PORT}) )
  {
    eval("use IO::Socket::INET");
    if ( $@ ) { undef $ENV{PHEDEX_UDP_PORT}; }
  };
}

sub Logmsg
{   
  my $self = shift;
  print $self->Hdr, @_,"\n";
}

sub Notify
{
  my $self = shift;
  my $port = $ENV{PHEDEX_UDP_PORT};
  return unless defined $port;

  my $socket = IO::Socket::INET->new( Proto => 'udp' );
  my $server = pack_sockaddr_in( $port, inet_aton("127.0.0.1") );
  my $message = join('',$self->Hdr,@_,"\n");
  send( $socket, $message, 0, $server );
}

sub Alert
{   
  my $self = shift;
  $self->Logmsg ("alert: ", @_);
  $self->Notify ("alert: ", @_);
}

sub Warn
{   
  my $self = shift;
  $self->Logmsg ("warning: ", @_);
  $self->Notify ("warning: ", @_);
}   

sub Dbgmsg
{
  my $self = shift;
  $self->Logmsg ("debug: ", @_);
}

sub Fatal
{
  my $self = shift;
  $self->Logmsg ("fatal: ", @_);
  $self->Notify ("fatal: ", @_);
  exit(1);
}

sub Note
{
  my $self = shift;
  print $self->Hdr," note: ", @_, "\n";
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
