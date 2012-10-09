package PHEDEX::Namespace::SpaceCountCommon;
our @ISA = qw(Exporter);
our @EXPORT = qw (dirlevel convertToUnixTime );

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
  my ($pathSimple,$temp1);
  my $path=shift;
  my $depth=shift;
  my @tmp=();
  if  ( not $path =~ /^\//){ die "ERROR: path does not start with a slash:  \"$path\"";}
  if  ( $path = ~ /^(\S+\/cms)(\/\S+)$/) {
      $temp1 = $1;
      $pathSimple = $2;
  }      
  #$rootdir = $temp1;  # rootdir not used anywhere, but causes trouble as it is defined in outer scope.
  @tmp = split ('/', $pathSimple, $depth+2);
  pop @tmp;
  if (scalar(@tmp) > 2) {
     return join ("/", @tmp);
  }
  else {
     return $pathSimple;
  }
}

sub convertToUnixTime
{
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

1;
