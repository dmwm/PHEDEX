#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;
use Data::Dumper;
use Sys::Hostname;
use POSIX;
use PHEDEX::Core::Help;

##H
##H  This script is for monitoring CPU and memory use by any process belonging
##H to a given user or set of users. Ask Tony for details...
##H
##H  Comments, feedback, and bug-reports welcomed, via Savannah whenever
##H appropriate.
##H

my ($rss,$vsize,$cpu,%g,%cmds,%procs,%bad,@users);
my ($detail,%pids,$interval,$help,$verbose,$quiet,$log);
my (%thresh,$VSize,$RSS,$Utime,$Stime,$pagesize);

$interval = $detail = $quiet = $verbose = 0;

$VSize = 0;
$RSS   = 0;
$Utime = 0;
$Stime = 0;

GetOptions(	'interval=i'	=> \$interval,
		'detail'	=> \$detail,
		'help'		=> \&usage,
		'verbose'	=> \$verbose,
		'quiet'		=> \$quiet,
		'users=s@'	=> \@users,
		'VSize=i'	=> \$VSize,
		'RSS=i'		=> \$RSS,
		'Utime=i'	=> \$Utime,
		'Stime=i'	=> \$Stime,
		'log=s'		=> \$log,
	  );

die "Need one of VSize, RSS, Utime, Stime\n"
	unless ($VSize || $RSS || $Utime || $Stime);
#
# No user-serviceable parts below...
#

if ( $log )
{
  print "I am forking into the background, writing to $log. Byee!\n";

# Cribbed from PHEDEX::Core::Agent::daemon
  my $pid;
  die "failed to fork into background: $!\n" if ! defined ($pid = fork());
  close STDERR if $pid;
  exit(0) if $pid;

  die "failed to set session id: $!\n"       if ! defined setsid();
  die "failed to fork into background: $!\n" if ! defined ($pid = fork());
  close STDERR if $pid;
  exit(0) if $pid;

  open STDOUT, ">$log" or die "open: $log: $!\n";
  chmod 0600, $log or die "chmod: $!\n";
  open (STDERR, ">&STDOUT") or die "Can't dup STDOUT: $!";
  open (STDIN, "</dev/null");

  $|=1;
}

%thresh = (
		VSize	=> $VSize,
		RSS	=> $RSS,
		Utime	=> $Utime,
		Stime	=> $Stime,
	  );
print scalar localtime,": ($$) Thresholds are: ",
	map { "$_=$thresh{$_} " } sort keys %thresh;
print "\n";

open CONF, "getconf PAGESIZE|" or die "getconf PAGESIZE: $!\n";
$pagesize = <CONF>;
close CONF;
chomp $pagesize;
$pagesize or die "Cannot determine memory pagesize!\n";

LOOP:
%procs = ();

if ( ! @users ) { push @users, (getpwuid($<))[0]; } 

open PS, "ps aux | egrep '^" . join('|^',@users) . "' |" or die "ps: $!\n";
my @ps = <PS>;
close PS;
foreach ( @ps )
{
  m%^(\S+)\s+(\d+)\s% or next;
  my ($user,$pid) = ($1,$2);
  -e "/proc/$pid" or next;
  $procs{$pid} = 1;
  if ( !$cmds{$pid} )
  {
    open CMD, "/proc/$pid/cmdline" or do
    {
      warn "/proc/$pid/cmdline: $!\n";
      $cmds{$pid}='unknown';
      next;
    };
    $_ = <CMD>;
    next unless $_;
    chomp $_;
    $_ = join(' ',split('\c@',$_));
    $cmds{$pid} = "user=$user pid=$pid, cmd=$_";
    close CMD;
  }
}

foreach my $pid ( sort { $a <=> $b } keys %procs )
{
  open PROC, "</proc/$pid/statm" or do
  {
#   warn "/proc/$pid: $!\n";
    delete $procs{$pid};
    delete $cmds{$pid};
    next;
  };
  $_ = <PROC>;
  close PROC or die "Error closing /proc/$pid/statm: $!\n";
  my @a = split(' ',$_);
  my %h = ();
  $h{VSize} = $a[0] * $pagesize / 1024 / 1024; # in MB
  $h{RSS}   = $a[1] * $pagesize / 1024 / 1024;

  open PROC, "</proc/$pid/stat" or do { warn "/proc/$pid: $!\n"; next; };
  $_ = <PROC>;
  close PROC or die "Error closing /proc/$pid/stat: $!\n";
  my @b = split(' ',$_);
  $h{Utime} = $b[13] / 100; # normalise to seconds
  $h{Stime} = $b[14] / 100;
  my @l;
  foreach ( sort keys %thresh )
  {
    next unless $thresh{$_};
    if ( $h{$_} >= $thresh{$_} ) { push @l,$_; }
  }
  if ( @l )
  {
    if ( !$bad{$pid}++ ) { print scalar localtime,": Reporting $cmds{$pid}\n"; }
    print scalar localtime,": PID=$pid exceeded=>(",join(',',@l),') ',
	join(' ',map { "$_=" . int($h{$_}*100)/100 } sort keys %h),
	"\n";
  }
}

exit 0 unless $interval;
sleep $interval;

# A goto! Shame on me!
goto LOOP;
