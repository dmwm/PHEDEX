#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);

my ($in,$out,$json,$workflow,$payload,$cycletime);
GetOptions(
                'in=s'  => \$in,
                'out=s' => \$out,
          );
$in  || die "No input file specified\n";
$out || die "No output file specified\n";

open IN, "<$in" or die "open input $in: $!\n";

$json = <IN>;
close $in;
$payload = decode_json($json);
$workflow = $payload->{workflow};
$cycletime = $workflow->{CycleTime}+5; # Add a few seconds margin...

open VPINFO, 'voms-proxy-info --actimeleft |' or die "voms-proxy-info: $!\n";
my $left = <VPINFO>;
close VPINFO or die "close voms-proxy-info: $!\n";
chomp $left;

print "Time left on proxy: $left seconds\n";
if ( $left <= $cycletime+300 ) {
  print "Proxy has expired, this is fatal\n";
  $payload->{report} = { status => 'fatal', 'reason' => 'Proxy expired' };
}
open  OUT, ">$out" or die "open output $out: $!\n";
print OUT encode_json($payload);
close OUT;
exit 0;
