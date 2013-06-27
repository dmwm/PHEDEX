#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);

my ($in,$out,$json,$workflow,$payload,$src,$dst,@tmp,$status,$node);
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
$src = $workflow->{InputFile};
($dst = $workflow->{OutputFile}) =~ s|%ID%|$payload->{id}|;
print "Delete $dst\n";

$node = $workflow->{UberFTPHost} || $workflow->{RemoteHost};
open FTP, "uberftp $node 'cd $workflow->{RemotePath}; rm $dst' 2>&1 |" or
    die "uberftp: $!\n";
@tmp = <FTP>;
close FTP or do {
  $status = $!;
  print "close uberftp: $status\n";
  $payload->{report} = { status => 'error', reason => $status };
};

open  OUT, ">$out" or die "open output $out: $!\n";
print OUT encode_json($payload);
close OUT;

exit 0;
