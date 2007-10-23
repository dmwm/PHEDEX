#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use PHEDEX::Monalisa;
use PHEDEX::Core::Help;

##H
##H  This script is for monitoring CPU and memory use by agents. See the wiki
##H page at https://twiki.cern.ch/twiki/bin/view/CMS/PhedexProjAgentMonitoring
##H for details and instructions.
##H
##H  Comments, feedback, and bug-reports welcomed, via Savannah whenever
##H appropriate.
##H

my ($file,$node,$agent,$host,$site);
my ($pid,$rss,$vsize,$cpu,%g);
my (@pidfiles,$detail,%pids,$interval,$help,$verbose,$quiet);
my ($apmon_args,$prefix);
$interval = $detail = $quiet = $verbose = 0;
$site='';
$apmon_args='';
$prefix = 'PhEDEx_';

GetOptions(	'pidfiles=s'	=> \@pidfiles,
		'interval=i'	=> \$interval,
		'site=s'	=> \$site,
		'host=s'	=> \$host,
		'prefix=s'	=> \$prefix,
		'apmon=s'	=> \$apmon_args,
		'detail'	=> \$detail,
		'help'		=> \&usage,
		'verbose'	=> \$verbose,
		'quiet'		=> \$quiet,
	  );

die "Please specify your '--site' (short, acronym, e.g. FZK, RAL)\n"
	unless $site;

#
# If you _really_ know what you are doing, you might want to play with the
# arguments here. But you better be a Monalisa expert first!
#
$host = 'lxarda12.cern.ch:28884' unless $host;

# You will want to set these by hand, or on the command line, outside CERN!
@pidfiles = @ARGV if @ARGV;
@pidfiles = </data/*Nodes/*/state/*/pid> unless @pidfiles;

my %apmon_args = eval $apmon_args;
die "Error in apmon_args: $@\n" if $@;
my $apmon = PHEDEX::Monalisa->new (
		Cluster	=> 'PhEDEx',
                apmon	=>
                {
                  sys_monitoring => 1,
                  general_info   => 1,
                },
		verbose	=> $verbose,
		Host	=> $host,
		%apmon_args,
        );

#
# No user-serviceable parts below...
#
$verbose = 1 if ! $interval;
$prefix .= '_' unless $prefix =~ m%_$%;

LOOP:
print scalar localtime,"\n" unless $quiet;
foreach $file ( @pidfiles )
{
# $file =~ m%^/data/([^/]*)Nodes/([^/]+)/state/([^/]*)/pid% or next;
  $file =~ m%^.*/([^/]+)/state/([^/]*)/pid% or next;
  $node = $1;
  $agent = $2;
  my %h = (	Cluster	=> $node,
		Node	=> $agent,
	  );
  open PID, "<$file" or do { warn "open: $file: $!\n"; next; };
  $pid = <PID>;
  close PID;
  chomp $pid;
  defined($pid) or next;

  open PROC, "</proc/$pid/statm" or do { warn "/proc/$pid: $!\n"; next; };
  $_ = <PROC>;
  close PROC or die "Error closing /proc/$pid/statm: $!\n";
  my @a = split(' ',$_);
  $h{VSize} = $a[0] / 1024; # in MB
  $h{RSS}   = $a[1] / 1024;

  open PROC, "</proc/$pid/stat" or do { warn "/proc/$pid: $!\n"; next; };
  $_ = <PROC>;
  close PROC or die "Error closing /proc/$pid/stat: $!\n";
  my @b = split(' ',$_);
  $h{Utime} = $b[13] / 100; # normalise to seconds
  $h{Stime} = $b[14] / 100;

  $apmon->Send( \%h );

# Do we want to do this?
  $h{Node} = $h{Cluster} . '_' . $h{Node};
  $h{Cluster} = "$prefix${site}_Total";
  $apmon->Send( \%h );

  if ( $detail && ! $pids{$pid} )
  {
    $pids{$pid}++;
    $apmon->ApMon->addJobToMonitor($pid, '', $prefix . 'Detail', $h{Node} );
  }

  my $c = delete $h{Cluster};
  my $n = delete $h{Node};
  my %f;
  foreach ( keys %h )
  {
    if ( exists($g{$c}{$n}{$_}) )
    {
      $f{'d' . $_} = $h{$_} - $g{$c}{$n}{$_};
      if ( m%time$% )
      {
        $f{'d' . $_} = $f{'d' . $_} * 100 / $interval;
      }
    }
    $g{$c}{$n}{$_} = $h{$_};
  }
  if ( scalar keys %f )
  {
    $f{Cluster} = "$prefix${site}_Delta";
    $f{Node} = $n;
    $apmon->Send( \%f );
  }
  sleep 1;
}

exit 0 unless $interval;
sleep $interval;

# A goto! Shame on me!
goto LOOP;
