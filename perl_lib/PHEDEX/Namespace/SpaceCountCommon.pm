package PHEDEX::Namespace::SpaceCountCommon;
our @ISA = qw(Exporter);
our @EXPORT;

push (@EXPORT, qw (lookupFileSizeXml lookupTimeStampXml )); 
push (@EXPORT, qw (lookupFileSizeTxt lookupTimeStampTxt )); 
push (@EXPORT, qw (dirlevel findLevel convertToUnixTime createRecord doEverything ));

use Time::Local;
use Time::localtime;
use File::Basename;
use PHEDEX::Namespace::Common  ( qw / setCommonOptions / );
use DMWMMON::StorageAccounting::Core ( qw /openDump/ );

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


sub lookupFileSizeTxt{$_=shift; my ($file, $size, $rest) = split /\|/; if ($file) {return ($file, $size)} else {return 0 } }
sub lookupFileSizeXml{$_=shift; if (m/\S+\sname=\"(\S+)\"\>\<size\>(\d+)\<\S+$/)  {return ($1, $2)} else {return 0}}
sub lookupTimeStampXml{$_=shift; if (m/<dump recorded=\"(\S+)\">/) {return ($1)} else {return 0}}
sub lookupTimeStampTxt{$_=shift; my @ar= split /\./; return $ar[-2]} # pass filename as argument

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
    #print "Match for $pattern found in $_ \n";
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

sub doEverything {
  my ($ns, $dumpfile, $lookupFileSize, $lookupTimeStamp) = @_;
  my $timestamp   = -1; # invalid
  my $level       = $ns->{LEVEL};
  my $totalsize   = 0;
  my $totalfiles  = 0;
  my $totaldirs   = 0;
  my %dirsizes    = ();
  # we search for this directory and count levels starting from the depth where it is found:
  my $pattern = "/store/";
  my ($line,$time,$size,$file);
  my $dump = openDump($dumpfile);
  while ($line = <$dump>) { 
      ($file, $size) = $lookupFileSize->($line);
      if ($file) {
	  $totalfiles++;
	  my $dir = dirname $file;
	  $dirsizes{$dir}+=$size;
	  $totalsize+=$size;
      } else {
	  $time = $lookupTimeStamp->($line);
	  if ($time) {$timestamp=convertToUnixTime($time)};
      }
  }
  close $dump;
  $totaldirs = keys %dirsizes;
  if ($ns->{VERBOSE}) {
    print "total files: ", $totalfiles,"\n";
    print "total dirs:  ", $totaldirs, "\n";
    print "total size:  ", $totalsize, "\n";
    print "timestamp:  ", $timestamp, "\n";
  }
  # Try to get timestamp from the dumpfile name: 
  if ($timestamp < 0)
  {
      $timestamp = lookupTimeStampTxt($filebasename);
  }
  my $storeDepth = findLevel(\%dirsizes, $pattern);
  $level = $ns->{LEVEL};
  if ($storeDepth >0 ) {
      $level = $level + $storeDepth -1; # Subtract 1: if  /store/ is found on the first level, we do not want  $level to change.
      print "Add $storeDepth levels preceeding $pattern\n";
  };
  print "[INFO] Creating database record using aggregation level = $level ... \n" if $ns->{VERBOSE};
  $record=createRecord(\%dirsizes, $ns, $timestamp, $level);
  return $record;
}

1;
