package DMWMMON::SpaceMon::Format::TXT;
use strict;
use warnings;
use Data::Dumper;
use base 'DMWMMON::SpaceMon::StorageDump';

# Class methods: 

sub formattingHelp
{
    my $message = <<'EOF';
======== Formatting help =========
TXT formating recommendations: 

Content of each file: one line pre file with:
LFN (or PFN) | file size (bytes) | file creation date (epoch s) | checksum

e.g.

[lxplus441] $ head -1 LHCb-Disk.1312201138.txt
/lhcb/MC/MC10/ALLSTREAMS.DST/00010680/0000/00010680_00000028_1.allstreams.dst|4046740455|1305988966000|N/A

If a field is not available, write 'na' (e.g. the checksum will not be available for some storage implementations, no problem) 

For more details see: 
https://twiki.cern.ch/twiki/bin/view/LCG/ConsistencyChecksSEsDumps#Format_of_SE_dumps. 
===================================
EOF
    print $message;
}

#Object methods: 

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;
    return $self;
}

sub lookupFileSize
{
    my $self = shift;
    $_ = shift;
    my ($file, $size, $rest) = split /\|/;
    if ($file) {
	#print "Found match for file: $file and size: $size \n" if $self->{VERBOSE};
	return ($file, $size);
    } else {
	return ();
    }
}

1;
