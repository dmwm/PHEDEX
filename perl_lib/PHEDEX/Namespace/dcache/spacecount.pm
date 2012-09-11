package PHEDEX::Namespace::dcache::spacecount;
# Implements space accounting for dcache
use strict;
use warnings;

#my ($level,$datasvcUrl);

# Code from Utilities/testSpace/spaceInsert   <<<<<

use Time::Local;
use Time::localtime;
use File::Basename;
use PHEDEX::CLI::UserAgent;
use Getopt::Long qw /:config pass_through require_order /;
use PHEDEX::Core::Loader;
use PHEDEX::Namespace::SpaceCountCommon;



my (@pfn,$dump,$level,$result,$datasvcUrl,$command,$rootdir,$totalsize,$totalfiles,$totaldirs);
my ($timeFromXml);
my ($verbose,$debug,$terse,$force);
my %dirsizes = ();
$totalsize = 0;
my ($response,$content,$method,$timeout,$pua,$target,$node,%payload,%topsizes);

$datasvcUrl='https://cmsweb-testbed.cern.ch/dmwmmon/datasvc';
$level = 5;

# @fields defines the actual set of attributes to be returned
our @fields = qw / timestamp usagerecord /;

sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
# $self is an empty hashref because there is no external command to call
  my $self = {};
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  return $self;
}

sub execute
{
  my ($self,$ns,$dumpfile) = @_;
  print " NRTEST:  here the parse of the dump file $dumpfile will go\n";
  # Code from Utilities/testSpace/spaceInsert

  if ( $dumpfile ) {
    print "Begin to dump.....\n";
    parse_chimera_dump($dumpfile);
  }
}


######################### for test only ########################
# Functions from Utilities/testSpace/spaceInsert:


sub parse_chimera_dump {
  my ($file_dump) = @_;
  $totalfiles    = 0;
  $totaldirs     = 0;
  my ($line,$time);
  #my (@pfn,$dump,$level,$result,$datasvcUrl,$command,$rootdir,$totalsize,$totalfiles,$totaldirs);
  if ( $file_dump =~ m%.gz$% )
    { open DUMP, "cat $file_dump | gzip -d - |" or die "Could not open: $file_dump\n"; }
  elsif ( $file_dump =~ m%.bz2$% )
    { open DUMP, "cat $file_dump | bzip2 -cd - |" or die "Could not open: $file_dump\n"; }
  else
    { open(DUMP, "cat $file_dump |") or die  "Could not open: $file_dump\n"; }
  while ($line = <DUMP>){
	my ($size,$file);
	#chomp;
	if ($line =~ m/^\S+\s\S+\"(\S+)\"\S+\>(\d+)\<\S+$/) {
	   $file = $1;
	   $size = $2;
	   #$debug and print "$file:$size\n"; # print unconditionally
	   print "$file:$size\n";
	   $totalfiles++;
	   my $dir = dirname $file;
	   $dirsizes{$dir}+=$size;
	   $totalsize+=$size;
        }
        if ($line =~ m/^<dump recorded=\"(\S+)\">$/) {
           $time = $1;
        }
  }
  close DUMP;
  $timeFromXml = convertToUnixTime($time);
  
  $totaldirs = keys %dirsizes;
 # if ($debug) {   # print unconditionally
     print "total files: ", $totalfiles,"\n";
     print "total dirs:  ", $totaldirs, "\n";
     print "total size:  ", $totalsize, "\n";
     print "timestamp:  ", $timeFromXml, "\n";
 # }
}



###############################################

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
