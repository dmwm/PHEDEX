#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);

my ($in,$out,$json,$workflow,$payload);
$payload = {};
GetOptions(
                'in=s'  => \$in,
                'out=s' => \$out,
          );

open IN, "<$in" or die "open input $in: $!\n";
$json = <IN>;
close IN;
$payload = decode_json($json);
$workflow = $payload->{workflow};

$workflow->{counter}++;
print 'Counter: count=',$workflow->{counter},"\n";

open  OUT, ">$out" or die "open output $out: $!\n";
print OUT encode_json($payload);
close OUT;
exit 0;
