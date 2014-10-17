package DMWMMON::SpaceMon::Format::TXT;
use strict;
use warnings;
use Data::Dumper;
use base 'DMWMMON::SpaceMon::StorageDump';
 
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %args = (@_);
    map { $self->{$_} = $args{$_} } keys %args;
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;
    print Dumper ($self);
    return $self;
}

sub lookupFileSize 
{
    $_ = shift;
    if (m/^\S+\s(\/\S+)\s(\d+)$/) {
	return ($1, $2);
    } else {
	return 0;
    }
}

sub formattingHelp
{
    my $message = <<'EOF';

TXT formating recommendations: 

Content of each file: one line pre file with:

LFN (or PFN) | file size (bytes) | file creation date (epoch s) | checksum

e.g.

[lxplus441] $ head -1 LHCb-Disk.1312201138.txt
/lhcb/MC/MC10/ALLSTREAMS.DST/00010680/0000/00010680_00000028_1.allstreams.dst|4046740455|1305988966000|N/A

if a field is not available, write 'na' (e.g. the checksum will not be available for some storage implementations, no problem) 


For more details see: 
https://twiki.cern.ch/twiki/bin/view/LCG/ConsistencyChecksSEsDumps#Format_of_SE_dumps. 

EOF
    print $message;
}

1;
