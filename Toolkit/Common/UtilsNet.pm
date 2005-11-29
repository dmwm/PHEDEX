package UtilsNet; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(getfullhostname resolvehostname getURL);
require Socket;
use Net::hostent;

sub getfullhostname {
  my ($hostname) = @_;
  my ($name,$aliases,$addrtype,$length,@addrs);
  if (! defined $hostname) {
    chop($hostname = `hostname`);
  }
  ($name,$aliases,$addrtype,$length,@addrs) = CORE::gethostbyname($hostname);
  my @names = ($hostname, $name, split(' ', $aliases));
  foreach my $n (@names) {
    if ($n =~ /^[^.]+\.[^.]+/) { return $n; }
  }
  return $hostname;
}

sub resolvehostname {
  my @result = ();
  foreach my $hostname (@_) {
    my ($name,$aliases,$addrtype,$length,@addrs) = CORE::gethostbyname($hostname);
    my $realname = $hostname;
    foreach my $n ($name, split(' ', $aliases)) {
      if ($n =~ /^[^.]+\.[^.]+/) { $realname = $n; last }
    }
    push (@result, $realname);
  }
  return scalar @_ > 1 ? @result : $result[0];
}

my $urlprog = undef;
sub getURL
{
    my ($url) = @_;
    if (! defined $urlprog)
    {
	if (open (URL, "curl --version 2>&1 |")) {
	    $urlprog = "curl -f -g -q -s"; close (URL);
	} elsif (open (URL, "wget --version 2>&1 |")) {
	    $urlprog = "wget -q -O -"; close (URL);
	} else {
	    die "no curl or wget, cannot fetch $url\n";
	}
    }

    local $/; undef $/;
    open (URL, "$urlprog '$url' |")
	or die "cannot execute $urlprog: $!\n";
    my $result = <URL>;
    close (URL) or die "$urlprog failed: $!\n";

    return $result;
}

1;
