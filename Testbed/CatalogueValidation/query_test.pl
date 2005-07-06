#!/usr/bin/env perl
use warnings;
use strict;
use Getopt::Long;

my %args = ();
my %GUIDPFN =();

&GetOptions("help"        => \$args{HELPME},
	    "entries=f"   => \$args{ENTRIES},
	    "pattern=s"   => \$args{PATTERN},
	    "cat=s"       => \$args{CAT},
	    "jobs=f"      => \$args{JOBS},
	    "warmup"      => \$args{WARM},
	    "dump"        => \$args{DUMP});
my $elements = keys(%args);

if ($args{HELPME} || !$args{CAT} ||
    $args{WARM} && (!$args{PATTERN} || !$args{ENTRIES}) ||
    $args{DUMP} && (!$args{JOBS}) ||
    (!$args{WARM} && !$args{DUMP}) ){
    print "Usage:\n";
    print "--help:       this help message\n";
    print "--cat:        catalogue to use (allways needed)\n";
    print "----------------------WARMUP--------------------------------\n";
    print "--warmup:     perform catalogue warmup (dump PFNs)\n";
    print "--entries:    amount of Guid entries to dump to file\n";
    print "--pattern:    pattern for GUIDs to dump (include %s)\n";
    print "-----------------------DUMP---------------------------------\n";
    print "--dump:       dump full catalogue (PFNs) by using 16**3 GUID queries\n";
    print "--jobs:       number of jobs to start for dump test\n";
    exit 1;
}


&warmup($args{ENTRIES}, $args{CAT}, $args{PATTERN}) if ($args{WARM});
&dumppfns($args{CAT}, $args{JOBS}) if ($args{DUMP});






sub warmup {
    my ($files, $cat, $pat) = @_;
    my $count = 0;

    # check if guid.list and pfn.list already exist and remoce them if they do exist
    system("rm guids.list") if (-e "guids.list");
    system("rm pfn.list") if (-e "pfn.list");

    # lets start with a FClistGUIDPFN
    my @guidpfns = `FClistGuidPFN -u $cat -g -m $pat |grep -v Warning |grep -v Info`;
    print "max amount of guids found (FClistGuidPFN):".scalar(@guidpfns)."\n";

    foreach my $guidpfn (@guidpfns) {
	$count += 1;
	chomp $guidpfn;
	my ($guid, $pfn) = split(' ',$guidpfn);
	open(my $GUID_h,'>>guids.list');
	open(my $PFN_h,'>>pfn.list');
	print $GUID_h "$guid\n";
	print $PFN_h "$pfn\n";
	close($GUID_h);
	close($PFN_h);
	last if ($count == $files);
    }
    #lets do a check with FClistPFN
    @guidpfns = `FClistPFN -u $cat -q \"guid like \'$pat\'\" |grep -v Warning |grep -v Info`;
    print "max amount of guids found (FClistPFN):".scalar(@guidpfns)."\n";
}


sub dumppfns {
    my ($cat, $jobs) = @_;

    my $pat = '';
    my @hex = ('1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F');
    foreach my $x (@hex) {
	foreach my $y (@hex) {
	    foreach my $z (@hex) {
		$pat = "$pat $x$y$z\%";
	    }
	}
    }
# dump output to file or /dev/null
    my $file = '~/scratch0/POOL_perf/guidpfn_dump.test';
    my $null = '/dev/null';

# let's start the dance since we have the pattern    
    my $cmd = "time PFClistGuidPFN -u $cat -j $jobs -g -m $pat 1> $file";
    do {print "Problems executing $cmd\n"; exit 2} if system($cmd);

}
