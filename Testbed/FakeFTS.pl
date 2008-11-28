#!/usr/bin/env perl
use warnings;
use strict;
use PHEDEX::Core::Logging;
my ($cmd,@args) = @ARGV;
my ($me,$cache);

$cache = "/tmp/phedex";
$me = PHEDEX::Core::Logging->new();
$me->{ME} = 'FakeFTS';
$me->{NOTIFICATION_PORT} = $ENV{NOTIFICATION_PORT};
$me->{NOTIFICATION_HOST} = $ENV{NOTIFICATION_HOST};

sleep(2); # just for fun...

sub getFiles
{
  my $id = shift;
  open JOB, "<$cache/$id" or do
  {
    $me->Notify("JobID=$id not in cache: $!\n");
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

$me->Notify("Command=$cmd @args\n");
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
  if ( $args[1] eq '--verbose' )
  {
    print
"Request ID:     $id
Status:         Finished
Channel:        MADAGASCAR-CERN
Client DN:      /DC=ch/DC=cern/OU=Borg Units/OU=Users/CN=mmouse/CN=999999/CN=Mickey Mouse
Reason:         <None>
Submit time:    2008-02-29 22:06:41.808
Files:          $nfiles
Priority:       1
VOName:         cms
        Done:           $nfiles
        Active:         0
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
    print "Finished\n";
  }
  for ( my ($s,$d) = each %{$files} )
  {
    print
"  Source:       $s
  Destination:  $d
  State:        Done
  Retries:      0
  Reason:       error during  phase: [] 
  Duration:     0

";
  }
  unlink "$cache/$id";
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
			rand() * $i, rand() * $i * $i);
  $me->Notify("JobID=$id for $cmd @args\n");
  my $copyjob = $args[-1];
  symlink $copyjob, "$cache/$id";
  print $id,"\n";
}

exit 0;
