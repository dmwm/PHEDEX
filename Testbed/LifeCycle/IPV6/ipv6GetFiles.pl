#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);

my ($in,$out,$json,$workflow,$payload,@payloads,$dir,@tmp,$tmp);
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

# Find the files in the source directory
$dir = $workflow->{InputDirectory};
@tmp = sort <$dir/*>;
print "Found ",scalar @tmp," files: ",join(', ',@tmp),"\n";
foreach ( @tmp ) {
  $tmp = clone $payload;
  $tmp->{workflow}{File} = $_;
  push @payloads, $tmp;
}

open  OUT, ">$out" or die "open output $out: $!\n";
print OUT encode_json(\@payloads);
close OUT;

exit 0;
