#!/usr/bin/env perl

use warnings;
use strict;

use Data::Dumper;

my @files = @ARGV;

foreach my $file (@files) {
    my ($dest) = ($file =~ /(\d\d\d)/);
    open FILE, "< $file" or die $!;
    my $perl = join "", <FILE>;
    my $obj = eval ( $perl || '');
    die $@ if $@;
    close FILE or die $!;
    
    my $links = $Failure::Rates{FAIL_LINKS};
    
    foreach my $src ( sort keys %$links ) {
	my $oldfail = $links->{$src};
		
	my $newfail = $oldfail;
	if ( $oldfail == 0 && (rand() < 0.5) ) {     # 50% chance to make a perfect link a failing one
	    $newfail = (0.2 * rand()) + 0.1;     # between 10% and 30%
	} elsif ($oldfail != 0 && (rand() < 0.75) ) { # 75% chance to fix a failing link
	    $newfail = 0;
	}

	$newfail = sprintf '%0.2f', $newfail;
	print "$src->$dest failure rate from $oldfail to $newfail\n" if ($oldfail ne $newfail);
	$links->{$src} = $newfail;
    }

    my $dumper = new Data::Dumper([\%T0::System, \%Failure::Rates], ['*T0::System', '*Failure::Rates']);
    $dumper->Sortkeys(1);

    open FILE, "> $file" or die $!;
    print FILE q{print scalar localtime,": Loading PhEDEx per-link failure rates\n";}, "\n\n";
    print FILE $dumper->Dump();
    print FILE "1;\n";
    close FILE or die $!;
}
