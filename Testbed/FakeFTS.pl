#!/usr/bin/env perl
use warnings;
use strict;
use PHEDEX::Core::Logging;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Command;
use File::Path;
my ($cmd,@args) = @ARGV;
my ($me,$cache,$rate,$size,$debug);

# set these environment variables in the configuration to alter the behavior of this script
# default rate settings will make the "job" last 20 seconds per file
$cache = $ENV{PHEDEX_FAKEFTS_CACHEDIR} || '/tmp/' . (getpwuid($<))[0] . '/';
$rate  = $ENV{PHEDEX_FAKEFTS_RATE} || 100 * (1024**2); # MB/s
$size  = $ENV{PHEDEX_FAKEFTS_SIZE} ||   2 * (1024**3); # 2 GB
$me = PHEDEX::Core::Logging->new();
$me->{ME} = 'FakeFTS';
$me->{NOTIFICATION_PORT} = $ENV{NOTIFICATION_PORT};
$me->{NOTIFICATION_HOST} = $ENV{NOTIFICATION_HOST};
$debug = $ENV{PHEDEX_GLITE_DEBUG} || 0;

-d $cache || mkpath([$cache]) || die "Cannot find or create $cache directory\n";

sub getFiles
{
  my $id = shift;
  open JOB, "<$cache/$id" or do
  {
    $debug && $me->Notify("JobID=$id not in cache: $!\n");
    print "Failed\n";
    exit 0;
  };
  my $h;
  while ( <JOB> )
  {
    m%^(\S+)\s+(\S+)$% or next;
    $h->{$1} = $2;
  }
  close JOB;
  return $h;
}

$debug && $me->Notify("Command=$cmd @args\n");
if ( $cmd eq 'glite-transfer-list' )
{
# list a queue...
# Ignore this, wouldn't know how to deal with it anyway!
}

if ( $cmd eq 'glite-transfer-status' )
{
# list a job...
  my $id = $args[-1];
  my $files = getFiles($id);
  my $nfiles = scalar keys %{$files};
  my $start = &input("$cache/${id}.start");
  my $startstamp = &formatTime($start, 'stamp');
  $startstamp =~ s/ UTC$//;
  my $duration = &mytimeofday() - $start;
  my $ndone = int(($rate*$duration)/$size);
  $ndone = $nfiles if $ndone >= $nfiles;
  my $nactive = $nfiles - $ndone;
  my $status = $nactive ? "Active" : "Finished";

  if ( $args[1] && $args[1] eq '--verbose' )
  {
    print
"Request ID:     $id
Status:         $status
Channel:        MADAGASCAR-CERN
Client DN:      /DC=ch/DC=cern/OU=Borg Units/OU=Users/CN=mmouse/CN=999999/CN=Mickey Mouse
Reason:         <None>
Submit time:    $startstamp
Files:          $nfiles
Priority:       1
VOName:         cms
        Done:           $ndone
        Active:         $nactive
        Pending:        0
        Ready:          0
        Canceled:       0
        Failed:         0
        Finishing:      0
        Finished:       0
        Submitted:      0
        Hold:           0
        Waiting:        0
";
  }
  else
  {
    print "$status\n";
  }
  if ( $args[0] && $args[0] eq '-l' )
  {
    my $n = 0;
    foreach my $s ( sort keys %{$files} )
    {
      my $d = $files->{$s};
      my $state = $n < $ndone ? "Done" : "Active";
      print "\n" unless $n == 0;
      print
"  Source:       $s
  Destination:  $d
  State:        $state
  Retries:      0
  Reason:       error during  phase: [] 
  Duration:     0
";
      $n++;
     
    }
  }

  if ( !$nactive ) {
#   open LOG, ">>$cache/log.$id"; $|=1;
    my ($dead,$sentinel,$h,$old,$age,$candidate);
    $sentinel = "$cache/dead.sentinel";
    $dead     = "$cache/dead.jobs";
    $old      = time - 7200; # hard-code two hour timeout
#   print LOG "old age at $old\n";
    while ( -f $sentinel ) {
#     print LOG "Waiting for sentinel file...\n";
      sleep 1;
    }
    open SENTINEL, ">$sentinel";
#   print LOG "Opened $sentinel at ",time(),"\n";
    open DEAD, "<$dead" and do {
      while ( <DEAD> ) {
        chomp;
        m%^(\S+)\s+(\d+)$% or next;
        $candidate = $1;
        $age = $2;
        if ( $age > $old ) {
#         print LOG "$candidate too young ($age > $old)\n";
          $h->{$candidate} = $age;
        } else {
#         print LOG "unlink $candidate\n";
          unlink "$cache/$candidate"       if -f "$cache/$candidate";
          unlink "$cache/$candidate.start" if -f "$cache/$candidate.start";
          unlink "$cache/log.$candidate"   if -f "$cache/log.$candidate";
        }
      }
    };
    $h->{$id} = time() unless defined $h->{$id};
    open DEAD, ">$dead" and do {
      foreach ( keys %{$h} ) {
        print DEAD $_,' ',$h->{$_},"\n";
      }
      close DEAD;
    };
    close SENTINEL;
    unlink $sentinel;
#   print LOG "unlinked $sentinel\n";
#   close LOG
  }
}

if ( $cmd eq 'glite-transfer-cancel' )
{
# cancel a job...
# Null action, nothing to do...
}

if ( $cmd eq 'glite-transfer-setpriority' )
{
# set job priority...
# Null action, nothing to do...
}

if ( $cmd eq 'glite-transfer-submit' )
{
# submit a job... Fake a job-ID.
  my $i = 16*16*16*16;
  my $id = sprintf("%08x-%04x-%04x-%04x-%04x%08x",
			rand() * $i * $i,
			rand() * $i,
			rand() * $i,
			rand() * $i,
			$$,time);
#			rand() * $i, rand() * $i * $i);
  $debug && $me->Notify("JobID=$id for $cmd @args\n");
  my $copyjob = $args[-1];
  &output("$cache/${id}.start", &mytimeofday());
  symlink $copyjob, "$cache/$id";
  
  print $id,"\n";
}

exit 0;

