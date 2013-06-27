#!/usr/bin/perl -w -I/afs/cern.ch/user/w/wildish/public/perl -I/afs/cern.ch/user/w/wildish/public/perl/lib -I/afs/cern.ch/user/w/wildish/public/perl/lib/arch

use strict;
use JSON::XS;

my ($dir,@files,$file,$src,$dst,@src,@dst,@e,$e,$i,@h,$h,$g);
my ($start,$stop,$status,$duration,$size,$rate,$now,$json);
my ($mean,$min,$max,$period,%periods,@periods,$tStart,$tStep);
my ($errorWindow,@eTmp,$debug);
$errorWindow = 86400*3;
$debug = shift;
%periods = (
		  3600	=> 'last hour',
		 86400	=> 'last day',
	99_999_999_999	=> 'epoch',
	   );
map { push @periods, $periods{$_} } sort { $a <=> $b } keys %periods;
map { $periods{$periods{$_}} = $_; delete $periods{$_} } keys %periods;

$dir='/data/ipv6/PHEDEX/Testbed/LifeCycle/IPV6';
chdir $dir or die "chdir $dir: $!\n";

$tStep = 3600; # interval for binning errors; seconds
$tStart = $now = time;
@files = <results/current/putFile*.log*>;
foreach ( @files ) {
  m%^results/current/putFile\.([^_]+)_to_(.+)\.log(\.\d+)?$% or die "$_: cannot parse filename\n";
  $src = $1;
  $dst = $2;
  $h->{src}{$src}++;
  $h->{dst}{$dst}++;
  $h->{$src}{$dst} = {} unless defined $h->{$src}{$dst};
  $g = $h->{$src}{$dst};

  $file = $_;
  open FILE, "<$file" or die "open $file: $!\n";
  $debug && print "Reading $file\n";
  while ( <FILE> ) {
    $debug && print;
#    m%^(\S+) (\S+) (\S+) (\S+) (\d*) (\S+) (\d+)$% or die "($file) cannot parse \"$_\"\n";
#    $start     = $3;
#    $stop      = $4;
#    $status    = $5 || 0;
#    $duration  = $6;
#    $size      = $7;
    m%^(\S+) (\S+) (\d*) (\S+) (\d+)$% or die "($file) cannot parse \"$_\"\n";
    $start     = $1;
    $stop      = $2;
    $status    = $3 || 0;
    $duration  = $4;
    $size      = $5;

    if ( $start < $tStart ) { $tStart = $start; }

    $rate = $size/(1024*1024) / $duration;
    $rate = int ( $rate * 1000 ) / 1000;
    foreach $period ( @periods ) {
      $g->{$period}{errors} = 0 unless defined $g->{$period}{errors};
      if ( $now - $stop < $periods{$period} ) {
        $g->{$period}{status}{$status}++;
        if ( $status ) {
          if ( !$e->{$period}{int($stop)}{$src}{$dst}++ ) {
            $g->{$period}{errors}++;
            push @e, { source => $src, destination => $dst, status => $status, start => int($start), stop => int($stop), time => int($stop) }
              if $period eq 'epoch';
          }
        } else {
          push @{$g->{$period}{rate}}, $rate;
        }
      }
    }
    $g->{epoch}{data}{$stop} = { rate => $rate, status => $status };
  }
}

$tStart = 86400 * int( $tStart / 86400 );
$i = int( ($now-$tStart) / $tStep );
$debug && print "$i steps\n";
@h = (0) x $i;
foreach ( @e ) {
  $i = int( ($_->{time}-$tStart) / $tStep + 0.5 );
  $h[$i]++;
  push @eTmp, $_ if  $now - $_->{time} < $errorWindow;
}

delete $h->{src};
delete $h->{dst};

$json = encode_json(\@periods); print 'order = ',$json,";\n";
$json = encode_json($h);        print 'stats = ',$json,";\n";
$json = encode_json(\@eTmp);    print 'errs = ',$json,";\n";
$json = encode_json(\@h);       print 'hchart = ',$json,";\n";
print 'tStart = ',$tStart,";\n";
print "// All done!\n";
