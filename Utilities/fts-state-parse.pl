#!/usr/bin/env perl

# example line:
# 2008-03-14 18:19:32: QMon[9663]: STATISTICS: TIME=0 FILES: Total=1703 undefined=1703

my $jobs = [];
my $files = [];
my $type, %allfields;
while (<>) {
    chomp;
    next unless /QMon.*STATISTICS/;
    if (/FILES/)   { $type = $files; }
    elsif (/JOBS/) { $type = $jobs; }
    
    my ($date) = (/^(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d):/);
    my @fields = split /\s+/, $_;
    @fields = grep /=/, @fields;
    my %data = map { split /=/, $_ } @fields;
    $allfields{$_} = 1 foreach keys %data;
    $data{DATE} = $date;
    push @{$type}, \%data;
}

my @fields = sort keys %allfields;
unshift @fields, 'DATE';

my %files = ( 'jobs.csv' => $jobs,
	      'files.csv' => $files );

foreach my $file (keys %files) {
    open FILE, '>', $file;
    print FILE join(',', @fields), "\n";
    foreach my $data (@{$files{$file}}) {
	print FILE join(',', @{$data}{@fields}), "\n";
    }
    close FILE;
}
