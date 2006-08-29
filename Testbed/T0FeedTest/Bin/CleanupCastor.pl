#!/usr/bin/perl -w
use strict;
use T0::Iterator::Rfdir;
use Getopt::Long;

my ($hammer,$verbose,$dir,$root);
my ($cmd,$file,@files,$i,$j,$iterator);
$hammer = $verbose = 0;
$root = '/castor/cern.ch/cms';
GetOptions(     "verbose"     => \$verbose,
		"hammer"      => \$hammer,
                "directory=s" => \$dir,
          );

$i = 5;
$j = 0;

defined($dir) or die "Expecting a '--directory'\n";
$dir =~ m%^$root% or die "Won't kill files outside $root!\n";

$iterator = T0::Iterator::Rfdir->new( Directory => $dir);
while ( $file = $iterator->Next() )
{
  $verbose && print "$file\n";
  push @files, $file;
  if ( scalar @files >= $i )
  {
    $cmd = "stager_rm -M " . join(' -M ',@files);
    $verbose && print $cmd,"\n";
    open CMD, "$cmd |" or die "$cmd: $!\n";
    while ( <CMD> ) { print if $verbose; }
    close CMD or die "close: $cmd: $!\n";
    @files=();
    $j += $i;
    print "Cleaned $j files...      \r";
  }
}

if ( scalar @files )
{
  $cmd = "stager_rm -M " . join(' -M ',@files);
  $verbose && print $cmd,"\n";
  open CMD, "$cmd |" or die "$cmd: $!\n";
  while ( <CMD> ) { print if $verbose; }
  close CMD or die "close: $cmd: $!\n";
  @files=();
  $j += $i;
}
print "Cleaned $j files...      \n";
exit 0 unless $hammer && $j;
print "\nFinal pass, hammering them to death in 30 seconds...\n";
sleep 30;

$j=0;
$iterator = T0::Iterator::Rfdir->new( Directory => $dir);
while ( $file = $iterator->Next() )
{
  $cmd = "stager_rm -M $file";
  $verbose && print $cmd,"\n";
  open CMD, "$cmd |" or die "$cmd: $!\n";
  while ( <CMD> ) { print if $verbose; }
  close CMD or warn "close: $cmd: $!\n";

  $cmd = "nsrm $file";
  $verbose && print $cmd,"\n";
  open CMD, "$cmd |" or die "$cmd: $!\n";
  while ( <CMD> ) { print if $verbose; }
  close CMD or warn "close: $cmd: $!\n";
  $j++;
}
print "Finished. Hammered $j files...\n";
