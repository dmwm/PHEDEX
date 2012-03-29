#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);
use Data::Dumper;

my ($in,$out,$json,$workflow,$payload,$event,$id,$status);
my ($tmp,$datasets,$blocks,$files,$generator,$data,$xml,@xml,$dbs);
my ($i,$j,$k,$dataset,$block,$file,$dataFile,$blocksFile,$filesFile);
my ($InjectionsPerBlock,$InjectionsThisBlock,$BlocksPerDataset,$BlocksThisDataset);

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
$InjectionsPerBlock  = $workflow->{InjectionsPerBlock};
$InjectionsThisBlock = $workflow->{InjectionsThisBlock} || 0;
$BlocksPerDataset    = $workflow->{BlocksPerDataset};
$BlocksThisDataset   = $workflow->{BlocksThisDataset} || 1; # Assume it already has a block
print "$BlocksThisDataset blocks, $InjectionsThisBlock injections this block\n";
print "$BlocksPerDataset blocks/dataset, $InjectionsPerBlock injections/blocks\n";

$generator = 'generator --system phedex';
$dataFile   = $tmp . 'datasets-' . $id . '.json';
$blocksFile = $tmp . 'blocks-'   . $id . '.json';
$filesFile  = $tmp . 'files-'    . $id . '.json';

open  JSON, ">$dataFile" or die "open data file $dataFile: $!\n";
print JSON encode_json($workflow->{data});
close JSON;

$InjectionsThisBlock++;
if ( $InjectionsThisBlock >= $InjectionsPerBlock ) {
  $BlocksThisDataset++;
  if ( $BlocksThisDataset >= $BlocksPerDataset ) {
    print "All blocks are complete for this dataset, terminating.\n";
#   break the chain
    exit 0;
  }
  $InjectionsThisBlock = 0;
  print "Generate $blocks blocks\n";
  open GEN, "$generator --out $blocksFile --in $dataFile --action add_blocks --num $blocks |" or
	die "$generator: $!\n";
  while ( <GEN> ) { print; } close GEN or die "close $generator: $!\n";
  unlink $dataFile;
} else {
  $blocksFile = $dataFile;
}

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
push @{$payload->{events}}, ( 'Inject', $event );
$workflow->{InjectionsThisBlock} = $InjectionsThisBlock;
$workflow->{BlocksThisDataset}   = $BlocksThisDataset;
print "Write $out\n";
open  OUT, ">$out" or die "open output $out: $!\n";
print OUT encode_json($payload);
close OUT;
exit $status;
