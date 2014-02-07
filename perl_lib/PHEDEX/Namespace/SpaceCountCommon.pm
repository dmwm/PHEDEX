package PHEDEX::Namespace::SpaceCountCommon;
our @ISA = qw(Exporter);
our @EXPORT = qw (dirlevel findLevel convertToUnixTime createRecord);

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
              "level=i" => 6,
              "force"   => 0,
              "url=s"   => 'https://cmsweb.cern.ch/dmwmmon/datasvc',
             );

PHEDEX::Namespace::Common::setCommonOptions( \%options );

sub dirlevel {
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

sub findLevel {
  # returns the depth of directory structure above the matching pattern
  my ($hashref, $pattern) = @_;  # pass reference to dirsizes hash and a pattern to match
  if ( grep {$match=index( $_, $pattern); if ($match>0) {
    print "Match for $pattern found in $_ \n";
    return split ( '/', substr $_, 0, $match);
  }
           } keys  %{$hashref}){
  }
  return -1;
}

sub convertToUnixTime {
# parses time formats like "2012-02-27T12:33:23.902495" or "2012-02-20T14:46:39Z" 
# and returns unix time or -1 if not parsable.
  my ($time) = @_;
  my $unixTime = -1;
  my ($unixTime, $localtime, $mon, $year, $d, $t, @d, @t);
  if ($time =~ m/^(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)\D+/)
    {$unixTime = timelocal($6, $5, $4, $3, $2-1, $1-1900)}
  #$localtime = localtime($unixTime);
  #print "the localtime:", $localtime->mon+1,"  ", $localtime->year+1900, "\n";
  return $unixTime;
}

sub createRecord {
  my $hashref = shift;  # Pass %dirsizes by reference
  my ($ns, $timestamp, $level) = @_;
  my (%payload,%topsizes);
  $payload{"strict"} = defined $ns->{FORCE} ? 0 : 1;
  $payload{"node"}=$ns->{NODE};
  $payload{"timestamp"}=$timestamp;
  foreach  (keys %{$hashref}) {
    #$topsizes{ dirlevel($_, $level)}+=${$hashref}{$_} + 0; # for  leaves only
    for (my $p=1; $p <= $level; $p += 1) {
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
  return \%payload;
}

1;
