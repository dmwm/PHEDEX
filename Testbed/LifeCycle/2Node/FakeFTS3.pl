#!/usr/bin/env perl
use warnings;
use strict;
use PHEDEX::Core::Logging;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Command;
use JSON::XS;
use Data::Dumper;
use File::Path;
my ($cmd,@args) = @ARGV;
my ($me,$cache,$rate,$size,$debug);

# set these environment variables in the configuration to alter the behavior of this script
# default rate settings will make the "job" last 20 seconds per file
$cache = $ENV{PHEDEX_FAKEFTS_CACHEDIR} || '/tmp/' . (getpwuid($<))[0] . '/';
$rate  = $ENV{PHEDEX_FAKEFTS_RATE} || 12.5 * (1024**3); # bytes/s
$size  = $ENV{PHEDEX_FAKEFTS_SIZE} ||    2 * (1024**3); # bytes
$me = PHEDEX::Core::Logging->new();
$me->{ME} = 'FakeFTS3';
$me->{NOTIFICATION_PORT} = $ENV{NOTIFICATION_PORT};
$me->{NOTIFICATION_HOST} = $ENV{NOTIFICATION_HOST};
$debug = $ENV{PHEDEX_FTS_DEBUG} || 0;

-d $cache || mkpath([$cache]) || die "Cannot find or create $cache directory\n";

sub getFiles
{
  my $id = shift;
  my $file_data = do {
    open JOB, "<$cache/$id" or do {
      $debug && print "JobID=$id not in cache: $!\n";
      print "Failed\n";
      exit 0;
    };
    local $/;
    <JOB>
  };
  close JOB;

  my $h;
  eval {
    my $data = decode_json($file_data);
    # if multiple files, use just the first one
    for my $data_files (@{$data->{files}}) {
      $h->{@{$data_files->{sources}}[0]} = @{$data_files->{destinations}}[0];
    }
  };

  if ($@) {
     #$debug && print "# $id is not a json job\n";
     for ( split /\n/, $file_data ) {
        m%^(\S+)\s+(\S+)$% or next;
        $h->{$1} = $2;
     }
  }

  ($debug >=2 ) && print Dumper($h);
  return $h;
}

$debug && $me->Notify("Command=$cmd @args\n");
if ( $cmd eq 'fts-transfer-list' )
{
# list a queue...
# Ignore this, wouldn't know how to deal with it anyway!
}

if ( $cmd eq 'fts-transfer-status' )
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

  if ( $args[1] && $args[1] eq '--verbose' ) {
    print 
          "# Using endpoint : https://fts3-pilot-fake.cern.ch:8446\n".
          "# Client version : fake.1.0\n".
          "Request ID:      $id\n".
          "Status:          $status\n".
          "Client DN:       /DC=ch/DC=cern/OU=Borg Units/OU=Users/CN=mmouse/CN=999999/CN=Mickey Mouse\n".
          "Reason:          <None>\n".
          "Submission time: $startstamp\n".
          "Files:           $nfiles\n".
          "Priority:        1\n".
          "VOName:          cms\n".
          "        Done:           $ndone\n".
          "        Active:         $nactive\n".
          "        Pending:        0\n".
          "        Ready:          0\n".
          "        Canceled:       0\n".
          "        Failed:         0\n".
          "        Finishing:      0\n".
          "        Finished:       0\n".
          "        Submitted:      0\n".
          "        Staging:        0\n".
          "        Started:        0\n".
          "        Delete:         0\n".
          "        Hold:           0\n".
          "        Waiting:        0\n";
  }
  else {
    print "$status\n";
  }

  if ( $args[0] && $args[0] eq '-l' ) {
    my $n = 0;
    foreach my $s ( sort keys %{$files} ) {
      my $d = $files->{$s};
      my $state = $n < $ndone ? "Done" : "Active";
      print "\n" unless $n == 0;
      print "  Source:       $s\n".
            "  Destination:  $d\n".
            "  State:        $state\n".
            "  Staging:      0\n".
            "  Retries:      0\n".
            "  Reason:       None\n".
            "  Duration:     0\n";
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
#   close LOG;
  }
}

if ( $cmd eq 'fts-transfer-cancel' )
{
# cancel a job...
# Null action, nothing to do...
}

if ( $cmd eq 'fts-setpriority' )
{
# set job priority...
# Null action, nothing to do...
}

if ( $cmd eq 'fts-transfer-submit' )
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
  
  print "$id\n";
}

exit 0;

