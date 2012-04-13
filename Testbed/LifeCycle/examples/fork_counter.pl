#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);

my ($in,$out,$json,$workflow,$payload);
my ($i,@p,$p);
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

@p=();
foreach $i (1000, 2000, 3000) {
  $p = clone $payload;
  $p->{workflow}{counter} = $i;
  $p->{workflow}{Intervals}{counter} = 2 * int($i/1000);
  push @p,$p;
  print "fork_counter: create new workflow with counter=$i\n";
}

open  OUT, ">$out" or die "open output $out: $!\n";
print OUT encode_json(\@p);
close OUT;
exit 0;
