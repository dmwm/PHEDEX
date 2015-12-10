#! /usr/bin/env perl
# Examples and tests
use strict;
use warnings;
use Data::Dumper;
use DMWMMON::SpaceMon::Record;

my $VAR1;
my $file = $ARGV[0]; 
($file) or die "Please specify input file ";
print "Reading data from  file: $file \n";

#  Example based on RecordIO: 
my $data;
{
  local $/ = undef;
  open FILE, $file or die "Couldn't open file: $!";
  binmode FILE;
  $data = <FILE>;
  close FILE;
}
eval $data;  # $VAR1 now contains data service output data
#print Dumper ($VAR1);

# Assuming we have data for a single node (true for GetLastRecord API), 
# loop over the timestamps and create a record for each one
# (wrap this in a loop for multiple nodes): 

print "Node: ", $VAR1->{PHEDEX}{NODES}->[0]->{NODE}, "\n"; 

foreach my $timebin ( $VAR1->{PHEDEX}{NODES}->[0]->{TIMEBINS}) {
    foreach (keys %$timebin){
	my $record = DMWMMON::SpaceMon::Record->new();
	$record->setNodeName($VAR1->{PHEDEX}{NODES}->[0]->{NODE});
	$record->setTimeStamp($_);
	print "Timestamp = ", $_, "\n";
	foreach my $dirlist( $timebin->{$_}) {
	    foreach my $dir (@$dirlist) {
		print "DIR: ", $dir->{DIR}," = ", $dir->{SPACE}, "\n";
		$record->addDir($dir->{DIR},$dir->{SPACE});
	    }
	}
    }
}
