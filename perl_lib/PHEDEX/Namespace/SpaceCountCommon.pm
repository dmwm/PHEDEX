package PHEDEX::Namespace::SpaceCountCommon;
our @ISA = qw(Exporter);
our @EXPORT = qw (dirlevel convertToUnixTime createRecord);

use Time::Local;
use Time::localtime;
use PHEDEX::Namespace::Common  ( qw / setCommonOptions / );

# Note the structure: instead of the value being a variable that will hold
# the parsed value, we provide the default. Later, when the user wants to
# actually parse the command line arguments, they call
# PHEDEX::Namespace::Common::getCommonOptions, to set their options and
# parameter hashes automatically. Then they pass them to GetOptions.
our %options = (
              "dump=s" => undef,
              "node=s" => undef,
              "url=s"  => 'https://cmsweb-testbed.cern.ch/dmwmmon/datasvc',
              "level=i" => 6,
              "force"   => 0,
             );

PHEDEX::Namespace::Common::setCommonOptions( \%options );

sub dirlevel {
  print "NRDEBUG in dirlevel\n";
  my $path=shift;
  my $depth=shift;
  if  ( not $path =~ /^\//){ die "ERROR: path does not start with a slash:  \"$path\"";}
  my @tmp = split ('/', $path);
  my $topdir;
  if (@tmp <= $depth) {
    return $path;
  } else {
    $topdir = join ( '/', @tmp[0..$depth]);
    return $topdir;
  }
}

sub convertToUnixTime {
  my ($time) = @_;
  my ($unixTime, $localtime, $mon, $year, $d, $t, @d, @t);
  if ($time =~ m/^(\S+)T(\S+)Z$/)
    {
      $d = $1;
      @d = split /-/, $1;
      $t = $2;
      @t = split /:/, $2;
    }
  $unixTime = timelocal($t[2], $t[1], $t[0], $d[2], $d[1]-1, $d[0]-1900);
  #$localtime = localtime($unixTime);
  #print "the localtime:", $localtime->mon+1,"  ", $localtime->year+1900, "\n";
  return $unixTime;
}

sub createRecord {
  my $hashref = shift;  # Pass %dirsizes by reference
  my ($ns, $timestamp) = @_;
  my (%payload,%topsizes);
  $payload{"strict"} = defined $ns->{FORCE} ? 0 : 1;
  $payload{"node"}=$ns->{NODE};
  $payload{"timestamp"}=$timestamp;
  foreach  (keys %{$hashref}) {
    #$topsizes{ dirlevel($_, $ns->{LEVEL})}+=${$hashref}{$_} + 0; # for  leaves only
    for (my $p=1; $p <= $ns->{LEVEL}; $p += 1) {
      $topsizes{dirlevel($_,$p)}+=${$hashref}{$_};
    }
  }
  if ($debug) { print "dumping aggregated directory info......\n" };
  foreach ( keys %topsizes ) {
    $payload{$_} = $topsizes{$_} + 0;
  }
  my $count = 0;
  foreach  (keys %payload) {
    print "upload parameter: $_ ==> $payload{$_}\n";
    $count = $count+1;
  }
  print "total number of records: $count\n";
}

1;
