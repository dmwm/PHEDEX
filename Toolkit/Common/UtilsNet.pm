package UtilsNet; use strict; use warnings; use base 'Exporter';
our @EXPORT = qw(getfullhostname resolvehostname getURL);
require Socket;
use Net::hostent;

eval { require Sys::Hostname; };
$@ && print STDERR "No Sys::Hostname? You should consider installing it!\n";

sub getfullhostname {
  my ($hostname) = @_;

# Sys::Hostname exports hostname by default, but the debugger namespace
# confuses the issue. If you want consistant results in the debugger, you have
# to fully specify which hostname function you want to check the existance of.
  if ( defined(&Sys::Hostname::hostname) )
  {
#   No need to check it myself, hostname croaks if it can't find a name
    return Sys::Hostname::hostname();
  }

  my ($name,$aliases,$addrtype,$length,@addrs);
  if (! defined $hostname) {
    chop($hostname = `hostname`);
  }

  ($name,$aliases,$addrtype,$length,@addrs) = CORE::gethostbyname($hostname);
  my @names = ($hostname, $name, split(' ', $aliases));
  foreach my $n (@names) {
    return $n if ($n =~ /^[^.]+\.[^.]+/ && $n !~ /\.local$/);
  }
  defined $hostname or die "Cannot get hostname, spitting the dummy...\n";
  return $hostname;
}

sub resolvehostname {
# This appears to be redundant, I can find no code that calls it... TW.
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
