require Socket;
use Net::hostent;

sub getfullhostname {
  my($hostname,$name,$aliases,$addrtype,$length,@addrs);
  chop($hostname = `hostname`);
  ($name,$aliases,$addrtype,$length,@addrs) = CORE::gethostbyname($hostname);
  my @names = ($hostname, $name, split(' ', $aliases));
  foreach my $n (@names) {
    if ($n =~ /^[^.]+\.[^.]+/) { return $n; }
  }
  return $hostname;
}
