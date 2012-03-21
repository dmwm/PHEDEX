#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);
use Data::Dumper;

my ($in,$out,$json,$workflow,$payload,$event,$id,$status);
my ($tmp,$datasets,$blocks,$files,$generator);
my ($datasetsFile,$blocksFile,$filesFile);
GetOptions(
                'in=s'  => \$in,
                'out=s' => \$out,
          );
$in  || die "No input file specified\n";
$out || die "No output file specified\n";
$status = 0;

open IN, "<$in" or die "open input $in: $!\n";

$json = <IN>;
close IN;
$payload   = decode_json($json);
$workflow  = $payload->{workflow};
$event	   = $workflow->{Event};
$id	   = $payload->{id};
$datasets  = $workflow->{Datasets};
$blocks    = $workflow->{Blocks};
$files     = $workflow->{Files};
$tmp       = $workflow->{TmpDir};
$generator = 'generator --system phedex';

$datasetsFile	= $tmp . 'datasets-' . $id . '.json';
$blocksFile	= $tmp . 'blocks-'   . $id . '.json';
$filesFile	= $tmp . 'files-'    . $id . '.json';
print "Generate $datasets datasets\n";
open GEN, "$generator --generate datasets --out $datasetsFile --num $datasets |" or
	die "$generator: $!\n";
while ( <GEN> ) { print; } close GEN or die "close $generator: $!\n";

print "Generate $blocks blocks\n";
open GEN, "$generator --out $blocksFile --in $datasetsFile --action add_blocks --num $blocks |" or
	die "$generator: $!\n";
while ( <GEN> ) { print; } close GEN or die "close $generator: $!\n";
unlink $datasetsFile;

print "Generate $files files\n";
open GEN, "$generator --out $filesFile --in $blocksFile --action add_files --num $files |" or
	die "$generator: $!\n";
while ( <GEN> ) { print; } close GEN or die "close $generator: $!\n";
unlink $blocksFile;

open JSON, "<$filesFile" or die "open $filesFile: $!\n";
$json = <JSON>;
close JSON;
unlink $filesFile;
eval {
  $payload->{data} = decode_json($json);
};
if ( $@ ) { warn $@; }
print "Read $json\n";

print Dumper($payload),"\n";

open  OUT, ">$out" or die "open output $out: $!\n";
print OUT encode_json($payload);
close OUT;
exit $status;
