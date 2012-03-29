#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);
use Data::Dumper;

my ($in,$out,$json,$workflow,$payload,$event,$id,$status);
my ($tmp,$datasets,$blocks,$files,$generator,$data,$xml,@xml,$dbs);
my ($i,$j,$k,$dataset,$block,$file,$datasetsFile,$blocksFile,$filesFile);
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
$dbs       = $workflow->{DBS} || 'http://cmsdoc.cern.ch/cms/aprom/DBS/CGIServer/query';
$generator = 'generator --system phedex';

$datasetsFile	= $tmp . 'datasets-' . $id . '.json';
$blocksFile	= $tmp . 'blocks-'   . $id . '.json';
$filesFile	= $tmp . 'files-'    . $id . '.json';
print "Generate $datasets datasets\n";
open GEN, "$generator --generate datasets --out $datasetsFile --num $datasets |" or
	do {
  $payload->{report} = { status => 'fatal', reason => "$generator: $!" };
  $status = -2;
  goto COP_OUT;
};
while ( <GEN> ) { print; }
if ( !close GEN ) {
  $payload->{report} = { status => 'fatal', reason => "close $generator: $!" };
  $status = -1;
  goto COP_OUT;
};

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

print "Read $filesFile\n";
open JSON, "<$filesFile" or die "open $filesFile: $!\n";
$json = <JSON>;
close JSON;
unlink $filesFile;
eval {
  $data = decode_json($json);
};
if ( $@ ) { warn $@; }

$workflow->{data} = $data;

# TW TODO: when I can pass the DBS to the generator, this can be cleaned up
$dbs = $dbs || $data->[0]{dataset}{dbs_name} || $data->{dbs_name} || $dbs;
@xml = (
	 "<data version=\"2.0\">",
	 "  <dbs name=\"$dbs\" dls=\"dbs\">"
       );
foreach $i ( @{$data} ) {
  $dataset = $i->{dataset};
  push @xml, "    <dataset name=\"$dataset->{name}\" is-open=\"$dataset->{'is-open'}\">";
  foreach $j ( @{$dataset->{blocks}} ) {
    $block = $j->{block};
    push @xml, "      <block name=\"$block->{name}\" is-open=\"$block->{'is-open'}\">";
    foreach $k ( @{$block->{files}} ) {
      $file = $k->{file};
      push @xml, "      <file name=\"$file->{name}\" bytes=\"$file->{bytes}\" checksum=\"$file->{checksum}\" />";
    }
    push @xml, "      </block>";
  }
  push @xml, "    </dataset>";
} 
push @xml, "  </dbs>";
push @xml, "</data>";
$xml = join("\n",@xml);
$workflow->{XML} = $xml;

COP_OUT:
print "Write $out\n";
open  OUT, ">$out" or die "open output $out: $!\n";
print OUT encode_json($payload);
close OUT;
exit $status;
