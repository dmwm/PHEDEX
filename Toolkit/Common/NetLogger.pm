# Perl module for logging.  Inspired by code by Tony Wildish,
# which was in turn inspired by code from Compass (Ulrich Fuchs)
# and NetLogger.

package NetLogger;
require 5.004;
require Exporter;
use vars qw(@ISA %tools);
@ISA = ('Exporter');

use strict;
use Socket;
use IO::Socket;
use Sys::Hostname;
# use Mail::Mailer;

# Initialise a new netlogger object.
sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  bless $self, $class;
  return $self;
}

# genstamp().  Generate NetLogger style "DATE=NNN" header stamp.
# Used by serverListen() if the incoming packet has no date field.
sub genstamp
{
  my @n = localtime;
  $n[4]++;
  $n[5]+=1900;
  return 'DATE=' . sprintf("%04d%02d%02d%02d%02d%02d",@n[5,4,3,2,1,0]) . ' ';
}

# ->serverListen(PORT [, PROTONAME]).  Listen for netlogger messages
# coming on PORT.  By default uses UDP datagram socket; if PROTONAME
# is 'tcp', uses TCP datagram sockets instead, which are reliable but
# slower.  Waits for messages on the socket and invokes serverNotify()
# with each received packet.
#
# FIXME: mailto, subject, from
sub serverListen
{
  # listener: prepare the listening socket
  my ($self, $port, $protoname) = @_;

  die if ! defined $port;
  $protoname = 'udp' if ! defined $protoname;
  my $host = hostname ();
  my $proto = getprotobyname('udp');
  socket(SRVSOCKET, PF_INET, SOCK_DGRAM, $proto)
    || die "cannot create socket: $!";
  setsockopt(SRVSOCKET, SOL_SOCKET, SO_REUSEADDR, 1) || die "setsockopt: $!";
  my $lname = gethostbyname ($host);
  my $laddr = pack_sockaddr_in ($port, $lname);
  bind(SRVSOCKET, $laddr)
    || die "cannot bind local socket: $!";

  # prepare fdset for listening to the socket
  my $rin = "";
  vec($rin,fileno(SRVSOCKET),1) = 1;

  # listen to the socket
  $self->serverNotify (&genstamp() . "NL.EVNT=LOGGER START\n");
  while (select ($rin, undef, undef, undef))
  {
    my $packet = <SRVSOCKET>;
    my $hdr = ($packet =~ /^DATE=/ ? '' : &genstamp);
    $self->serverNotify($hdr . $packet);
  }
  $self->serverNotify (&genstamp . "NL.EVNT=LOGGER STOP\n");
  close (SRVSOCKET);
}

# ->serverNotify(PACKET).  Invoked by serverListen() whenever a
# package arrives.  Default implementation just prints out the
# messages to STDOUT.  If a packet containing "ALARM" arrives,
# invokes serverAlarm() with the packet.
sub serverNotify
{
  my ($self, $packet) = @_;

  $| = 1;
  print $packet;
  $self->serverAlarm ($packet) if $packet =~ /ALARM/;
}

# ->serverAlarm(PACKET).  Invoked by serverNotify() for alarms.
# Send a mail to the "owner".  If the packet contains a field
# NOTIFY=addr@some.where, sends the notification there instead.
# If the packet contains field SUBJECT=some_text, uses it as
# the mail subject, otherwise uses "netlogger alarm".
sub serverAlarm
{
  my ($self, $packet) = @_;
  my $host = hostname ();
  my $notify = ($packet =~ /NOTIFY=(\S+)\b/ ? $1 : 'lassi.tuura@cern.ch'); # FIXME
  my $subject = ($packet =~ /SUBJECT=(\S+)\b/ ? $1 : 'netlogger alarm');
  my $mailer = undef; # new Mail::Mailer;
  $mailer->open({ From => "$0\@$host", To => $notify, Subject => $subject })
    || do { warn "cannot send a mail message: $!\n"; next; };
  print $mailer $_;
  $mailer->close();
}

# ->clientSetup(SERVER => 'fqdn.server.name', PORT => NN [, STAMP => 0/1]
#   [, PROTONAME => 'udp'/'tcp']).  Setup netlogger client using the hash
# arguments given.
sub clientSetup
{
  my $self = shift;
  my %args = (STAMP => 0, PROTONAME => 'udp', @_);

  die if ! defined $args{SERVER};
  die if ! defined $args{PORT};
  while (my ($k, $v) = each %args) {
    $self->{$k} = $v;
  }
}

# ->clientWrite(PACKET [, PACKET...]).  Write one or more packets to the
# netlogger server.  The client must have been previously configured with
# clientConfigure().
sub clientWrite
{
  my ($self, @packets) = @_;
  my $server = $self->{SERVER} || die "no netlogger server";
  my $port = $self->{PORT} || die "no netlogger port";
  my $stamp = $self->{STAMP} ? &genstamp() : '';
  my $hosthdr = "HOST=" . hostname() . " ";

  my $proto = getprotobyname($self->{PROTONAME});
  socket(CLISOCK, PF_INET, SOCK_DGRAM, $proto)
    || die "cannot create netlogger socket: $!";
  my $rname = gethostbyname($server)
    || die "no such netlogger server: $!";
  my $raddr = pack_sockaddr_in ($port, $rname);

  foreach my $packet (@packets)
  {
    my $out = (($packet =~ /DATE=\d+/ ? '' : $stamp)
    	       . ($packet =~ /HOST=/ ? '' : $hosthdr)
	       . $packet);
    send(CLISOCK, $out, 0, $raddr);
  }
  close(CLISOCK);
}

1;
