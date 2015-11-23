#! /usr/bin/env perl
# Examples and tests
use strict;
use warnings;
use Data::Dumper;

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
eval $data;
print Dumper ($VAR1);


foreach my $p (sort keys %$VAR1) {
    print "Key: ", $p, "\n";
}
