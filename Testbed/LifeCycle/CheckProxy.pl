#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);

my ($in,$out,$json,$workflow,$payload,$interval,$status,$gracePeriod,$event);
my ($minGrace,$left);
$payload = {};
$minGrace = 60;
$gracePeriod = $status = 0;
GetOptions(
                'in=s'  => \$in,
                'out=s' => \$out,
          );

if ( $in ) {
  open IN, "<$in" or die "open input $in: $!\n";

  $json = <IN>;
  close IN;
  $payload = decode_json($json);
  $workflow = $payload->{workflow};
  $event = $workflow->{Event};
  $interval = $workflow->{Intervals}{$event};
  $gracePeriod = $workflow->{GracePeriod} || $minGrace;
  if ( $gracePeriod < $minGrace ) { $gracePeriod = $minGrace; }
}

open VPINFO, 'voms-proxy-info --actimeleft |' or do {
  $payload->{report} = { status => 'fatal', 'reason' => "voms-proxy-info: $!" };
  $status = -1;
};
if ( !$status ) {
  $left = <VPINFO>;
  close VPINFO or do { 
    $payload->{report} = { status => 'fatal', 'reason' => "close voms-proxy-info: $!" };
    $status = -2;
  };
  $left = 0 unless defined $left;
  chomp $left;

  print "Time left on proxy: $left seconds\n";
  if ( $left <= 0 ) {
    print "Proxy has expired, this is fatal\n";
    $payload->{report} = { status => 'fatal', 'reason' => 'Proxy expired' };
  } elsif ( $left <= $gracePeriod ) {
    print "Proxy will expire in $left seconds, this is fatal\n";
    $payload->{report} = { status => 'fatal', 'reason' => 'Proxy about to expire' };
  }
  if ( $left > $gracePeriod * 20 ) {
    $interval = $gracePeriod * 10;
  } elsif ( $left > $gracePeriod * 5 ) {
    $interval = $gracePeriod * 2;
  } else {
    $interval = $gracePeriod / 3;
    if ( $interval < 10 ) { $interval = 10; }
  }
}
if ( $out ) {
  $workflow->{Jitter} = 0;
  $workflow->{Intervals}{$event} = int($interval);
  $payload->{events} = [ $event ];
  open  OUT, ">$out" or die "open output $out: $!\n";
  print OUT encode_json($payload);
  close OUT;
} else {
  if ( $payload->{report} ) {
    print $payload->{report}{status},': ',$payload->{report}{reason},"\n";
  }
}
exit $status;
