package DMWMMON::SpaceMon::Format::TXT;
use strict;
use warnings;
use Data::Dumper;
use base 'DMWMMON::SpaceMon::StorageDump';

# Required methods: 

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;
    return $self;
}

sub formattingHelp
{
    print "=" x 80 . "\n";
    print __PACKAGE__ . " formatting recommendations \n";
    print "=" x 80 . "\n";
    my $message = <<'EOF';
Storage dump file contains one line per each file with the following structure: 

LFN (or PFN) | file size (bytes) | file creation date (epoch s) | checksum

Examples of syntax accepted in current implementation: 

/full/path/to/the/file|12345678
/full/path/to/the/file | 12345678 
/full/path/to/the/file | 12345678 |<any string>

For more details see: 
https://twiki.cern.ch/twiki/bin/view/LCG/ConsistencyChecksSEsDumps#Format_of_SE_dumps. 
EOF
    print $message;
    print "=" x 80 . "\n";
}

sub lookupFileSize
{
    my $self = shift;
    $_ = shift;
    my ($file, $size, $rest) = split /\|/;
    if ($size) {
	print "Found match for file: $file and size: $size \n" if $self->{VERBOSE};
	return ($file, $size);
    } else {
	&formattingHelp();
	die "\nERROR: formatting error in " . __PACKAGE__ . " for line: \n$_" ;
    }
}

1;
