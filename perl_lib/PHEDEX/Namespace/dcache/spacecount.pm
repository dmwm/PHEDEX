package PHEDEX::Namespace::dcache::spacecount;
# Implements space accounting for dcache
use strict;
use warnings;

# Code from Utilities/testSpace/spaceInsert   <<<<<

use Time::Local;
use Time::localtime;
use File::Basename;
use Getopt::Long qw /:config pass_through require_order /;
use PHEDEX::Core::Loader;
use PHEDEX::Namespace::SpaceCountCommon;
use DMWMMON::StorageAccounting::Core;
use PHEDEX::Namespace::Common;
use Data::Dumper;

my ($totalfiles,$totaldirs,$timestamp,$level);
my $totalsize = 0;
my %dirsizes = ();
my $pattern = "/store/";  # will search for this directory and count levels starting from the depth where it is found

# @fields defines the actual set of attributes to be returned
our @fields = qw / timestamp usagerecord /;

sub new {
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
  my $self = { @_ };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  return $self;
}

sub execute {
  my ($self,$ns,$dumpfile) = @_;
  if ( $dumpfile ) {
    print "[INFO] Parsing storage dump in $dumpfile ... \n" if $ns->{VERBOSE};
    parse_chimera_dump($dumpfile,$ns);
    my $storeDepth = findLevel(\%dirsizes, $pattern);
    $level = $ns->{LEVEL};
    if ($storeDepth >0 ) {
      $level = $level + $storeDepth -1; # Subtract 1: if  /store/ is found on the first level, we do not want  $level to change.
      print "Add $storeDepth levels preceeding $pattern\n";
    };
    print "[INFO] Creating database record using aggregation level = $level ... \n" if $ns->{VERBOSE};
    return createRecord(\%dirsizes, $ns, $timestamp, $level);   
  }
}

######################### for test only ########################
# Functions from Utilities/testSpace/spaceInsert:

sub parse_chimera_dump {
  my ($file_dump, $ns) = @_;
  $totalfiles    = 0;
  $totaldirs     = 0;
  my ($line,$time);
  if ( $file_dump =~ m%.gz$% )
    { open DUMP, "cat $file_dump | gzip -d - |" or die "Could not open: $file_dump\n"; }
  elsif ( $file_dump =~ m%.bz2$% )
    { open DUMP, "cat $file_dump | bzip2 -cd - |" or die "Could not open: $file_dump\n"; }
  else
    { open(DUMP, "cat $file_dump |") or die  "Could not open: $file_dump\n" 
    }
  while ($line = <DUMP>) 
    {
      my ($size,$file);
      if ($line =~ m/^\S+\s\S+\"(\S+)\"\S+\>(\d+)\<\S+$/) 
        {
          $file = $1;
          $size = $2;
          print "$file:$size\n" if $ns->{DEBUG}>1;
          $totalfiles++;
          my $dir = dirname $file;
          $dirsizes{$dir}+=$size;
          $totalsize+=$size;
        }
      if ($line =~ m/^<dump recorded=\"(\S+)\">$/) {$time = $1}
    }
  close DUMP;
  $timestamp= convertToUnixTime($time);
  $totaldirs = keys %dirsizes;
  if ($ns->{VERBOSE}) {
    print "total files: ", $totalfiles,"\n";
    print "total dirs:  ", $totaldirs, "\n";
    print "total size:  ", $totalsize, "\n";
    print "timestamp:  ", $timestamp, "\n";
  }
}

###############################################

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
