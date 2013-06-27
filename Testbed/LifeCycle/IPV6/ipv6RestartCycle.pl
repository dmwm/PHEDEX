#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);
use Time::HiRes qw ( time );
use Data::Dumper;

my ($in,$out,$json,$workflow,$payload,$src,$dst,@tmp,$status);
my ($start,$stop,$duration,$drain);
GetOptions(
		'in=s'	=> \$in,
		'out=s'	=> \$out,
	  );
$in  || die "No input file specified\n";
$out || die "No output file specified\n";

open IN, "<$in" or die "open input $in: $!\n";

$json = <IN>;
close $in;
$payload = decode_json($json);
$workflow = $payload->{workflow};

$drain = $workflow->{TmpDir} . 'drain';
if ( -f $drain ) {
  print "Draining workflow due to presence of global sentinel file\n";
  exit 0;
}
$drain .= '.' . $workflow->{Name};
$drain =~ s% %-%g;
if ( -f $drain ) {
  print "Draining workflow due to presence of specific sentinel file\n";
  exit 0;
}

push @{$workflow->{Events}}, ( 'putFile', 'checkFile', 'clearFile', 'restartCycle' );

open  OUT, ">$out" or die "open output $out: $!\n";
print OUT encode_json($payload);
close OUT;

exit 0;
