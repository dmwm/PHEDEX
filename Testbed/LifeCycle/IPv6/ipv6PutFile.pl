#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Getopt::Long;
use Clone qw(clone);
use Time::HiRes qw ( time );
use Data::Dumper;

my ($in,$out,$json,$workflow,$payload,$src,$dst,@tmp,$status);
my ($start,$stop,$duration,$command);
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
$dst = $workflow->{RemoteProtocol} .
       $workflow->{RemoteHost} .
       $workflow->{RemotePath} . '/' . $dst;
$start = time();
print "Send $src to $dst\n";
print "Start at time ",scalar localtime($start),"\n";

$status = 0;
if ( $src !~ m%://% ) {
  $src = 'file://' . $src;
}
$command = 'globus-url-copy -vb ' . ($workflow->{UseIPv4} ? '' : '-ipv6');
open FTP, "$command $src $dst 2>&1 |" or
     die "globus-url-copy: $!\n";
while ( <FTP> ) { print; }
close FTP or do {
  $status = $! || $?;
  print "close globus-url-copy: $status\n";
  $payload->{report} = { status => 'error', reason => $status };
};
$stop = time();
print "End at time ",scalar localtime($stop),"\n";
$duration = int(($stop-$start)*1000)/1000;
print "$dst: $duration seconds\n";
#if ( ! $status ) { $payload->{stats}{duration} = $duration; }
$payload->{stats}{duration} = $duration;

my $now = time(); #scalar localtime;
my $log = 'results/current/putFile.' . $workflow->{Name} . '.log';
#my $SrcDst = $workflow->{Name};
#$SrcDst =~ s% to % %;
$log =~ s% %_%g;
$status = 0 unless defined $status;
open LOG, ">>$log";
#print LOG "$SrcDst $start $stop $status $duration $workflow->{InputFileSize}\n";
print LOG "$start $stop $status $duration $workflow->{InputFileSize}\n";
close LOG;

open  OUT, ">$out" or die "open output $out: $!\n";
print OUT encode_json($payload);
close OUT;

exit 0;
