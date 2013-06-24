#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);

my ($in,$out,$json,$workflow,$payload,$src,$dir,$node);
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
print "Check size of $src\n";

if ( $src =~ m%:% ) {
  $node = $workflow->{InputUberFTPHost} || $workflow->{InputHost};
  $src =~ m%^[^:]+://[^/]+(/(.*/)?)(.*)$%;
  $src = $3;
  $dir = $1;
  open FTP, "uberftp $node 'cd $dir; dir $src' |" or
      die "uberftp: $!\n";
  while ( <FTP> ) {
    if ( m%^\S+\s+\S+\s+\S+\s+\S+\s+(\d+)\s+.*\s+$src$% ) {
      $workflow->{InputFileSize} = $1;
    }
  }
  close FTP or do {
    print "close uberftp: $!\n";
  };
} else { # Assume file is local
  $workflow->{InputFileSize} = (stat($src))[7];
}

if ( !$workflow->{InputFileSize} ) {
  $payload->{report} = { status => 'fatal', reason => "Cannot determine size of input file ($src)" };
}
open  OUT, ">$out" or die "open output $out: $!\n";
print OUT encode_json($payload);
close OUT;

exit 0;
