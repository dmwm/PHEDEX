#!/usr/bin/env perl

# Roughly cleans up a messy CMSDIST checkout to include only the
# dependencies specified in a file.  Some manual work is required
# after running.
#
# The list of dependencies can be obtained by parsing the output of
# cmsBuild, and building a list of packages which it built.

use warnings;
use strict;

use Getopt::Long;

my $depfile;
my $skipfile;
my $cmsdist;
my $remove = 0;
GetOptions("dep-file=s"  => \$depfile,
	   "skip-file=s" => \$skipfile,
	   "cmsdist=s"   => \$cmsdist,
	   "remove"      => \$remove);

die "check arguments" unless $depfile && $cmsdist;

my @deps;
open DEPS, '<', $depfile or die $!;
while (<DEPS>) {
    chomp;
    next unless $_;
    push @deps, $_;
}
close DEPS or die $!;

my @skip;
if ($skipfile) {
    open SKIP, '<', $skipfile or die $!;
    while (<SKIP>) {
	chomp;
	next unless $_;
	push @skip, $_;
    }
    close SKIP or die $!;
}

foreach my $file ( <$cmsdist/*> ) {
    next unless -f $file;
    my @matches = grep($file =~ /$_/, @deps);
    my $is_dep = @matches ? 1 : 0;
    my $skip = grep($file =~ /$_/, @skip) ? 1 : 0;
    if ($is_dep && !$skip) {
	print "$file is a dependency (", join(' ', @matches), ")... keep\n";
    } elsif ( $skip ) {
	print "$file on skip list... keep\n";
    } else {
	print "$file is not a dependency... remove\n";
	unlink $file if $remove;
    }
}
