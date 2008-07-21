#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;
use Data::Dumper;
use PHEDEX::Monalisa;
use PHEDEX::Core::Help;
use PHEDEX::Core::Config;

##H
##H  This script is for monitoring CPU and memory use by agents. See the wiki
##H page at https://twiki.cern.ch/twiki/bin/view/CMS/PhedexProjAgentMonitoring
##H for details and instructions.
##H
##H  Comments, feedback, and bug-reports welcomed, via Savannah whenever
##H appropriate.
##H

my ($pid,$env,$cluster,$node,$cfg,$agent,$host,$site);
my (@agents,$rss,$vsize,$cpu,%g);
my ($detail,%pids,$interval,$help,$verbose,$quiet);
my ($apmon_args,$prefix,$state,$config,@configs);

$interval = $detail = $quiet = $verbose = 0;
$site = '';
$apmon_args = '';
$prefix = 'PhEDEx_';

GetOptions(	'config=s@'	=> \@configs,
		'interval=i'	=> \$interval,
		'site=s'	=> \$site,
		'host=s'	=> \$host,
		'prefix=s'	=> \$prefix,
		'apmon=s'	=> \$apmon_args,
		'state=s'	=> \$state,
		'detail'	=> \$detail,
		'help'		=> \&usage,
		'verbose'	=> \$verbose,
		'quiet'		=> \$quiet,
		'agents=s@'	=> \@agents,
	  );

die "Please specify your '--site' (short, acronym, e.g. FZK, RAL)\n"
	unless $site;

#
# If you _really_ know what you are doing, you might want to play with the
# arguments here. But you better be a Monalisa expert first!
$host = 'lxarda12.cern.ch:28884' unless $host;

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
$prefix .= '_' unless $prefix =~ m%_$%;

if ( $state )
{
  my $STATE;
  if ( open STATE, "<$state" )
  {
    while ( <STATE> )
    {
      chomp;
      $STATE .= $_;
    }
    my $g = do { no strict "vars"; eval $STATE; };
    warn "No valid state: $@\n" if $@;
    %g = %{$g};
  }
}

LOOP:
foreach $config ( @configs, @ARGV )
{
  $cfg = PHEDEX::Core::Config->new();
  print scalar localtime," : $config\n" unless $quiet;
  $cfg->readConfig($config);
  foreach $agent ( $cfg->select_agents(@agents) )
  {
    $env = $cfg->ENVIRONMENTS->{$agent->ENVIRON};
    $pid = $env->getExpandedString($agent->DROPDIR) . 'pid';
    -f $pid or next;
  
    $cluster = $env->getExpandedString('${PHEDEX_INSTANCE}_$PHEDEX_NODE');
    $node    = $agent->LABEL; # $2;

    my %h = (	Cluster	=> $cluster,
		Node	=> $node,
	    );
    open PID, "<$pid" or do { warn "open: $pid: $!\n"; next; };
    $pid = <PID>;
    close PID;
    chomp $pid;
    defined($pid) or next;

    open PROC, "</proc/$pid/statm" or do { warn "/proc/$pid ($node): $!\n"; next; };
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

#   Do we want to do this?
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
          my $i = time;
          my $j = $g{$c}{$n}{epoch};
          if ( $i && $j && $i != $j )
          {
            $f{'d' . $_} = $f{'d' . $_} * 100 / ($i - $j);
          }
        }
      }
      $g{$c}{$n}{$_} = $h{$_};
    }
    $g{$c}{$n}{epoch} = time;
    if ( scalar keys %f )
    {
      $f{Cluster} = "$prefix${site}_Delta";
      $f{Node} = $n;
      $apmon->Send( \%f );
    }
    sleep 1;
  }
}

if ( $state )
{
  open STATE, ">$state" or die "Cannot write to state file: $state: $!\n";
  print STATE Dumper(\%g);
  close STATE;
}
exit 0 unless $interval;
sleep $interval;

# A goto! Shame on me!
goto LOOP;
