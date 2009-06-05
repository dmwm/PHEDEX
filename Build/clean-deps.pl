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
my $cmsdist;
my $remove = 0;
GetOptions("dep-file=s" => \$depfile,
	   "cmsdist=s"  => \$cmsdist,
	   "remove"     => \$remove);

die "check arguments" unless $depfile && $cmsdist;

my @deps;
open DEPS, '<', $depfile or die $!;
while (<DEPS>) {
    chomp;
    next unless $_;
    push @deps, $_;
}
close DEPS or die $!;

print join("\n", @deps), "\n";

foreach my $file ( <$cmsdist/*> ) {
    my @matches = grep($file =~ /$_/, @deps);
    my $is_dep = @matches ? 1 : 0;
    if ($is_dep) {
	print "$file is a dependency (", join(' ', @matches), ")... keep\n";
    } else {
	print "$file is not a dependency... remove\n";
	unlink $file if $remove;
    }
}
