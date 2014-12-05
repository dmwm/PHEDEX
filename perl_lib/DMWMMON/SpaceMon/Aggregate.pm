package DMWMMON::SpaceMon::Aggregate;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use DMWMMON::SpaceMon::Record;

our %params = (
	      DEBUG => 1,
	      VERBOSE => 1,
	      LEVEL => 6,
	      # we search for this directory and count levels down from there:
	      STARTPATH => "/store/",
	      );
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %args = (@_);
    
    map { if (defined $args{$_}) {$self->{$_} = $args{$_}} else { $self->{$_} = $params{$_}} } keys %params;        
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;
    return $self;
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub createRecord {
# Does dumpfile parsing and aggregation:
    my $self = shift;
    my $dumpfile = shift;
    my ($size, $file, $dir);
    print "I am in ",__PACKAGE__,"->createRecord()\n" if $self->{VERBOSE};
    my $record= DMWMMON::SpaceMon::Record->new();
    print "Record initialized:\n", $record->dump() if $self->{DEBUG};
    print "Processing file $dumpfile->{DUMPFILE}\n" if $self->{VERBOSE};
    print $dumpfile->dump() if $self->{DEBUG};
    my $fh = $dumpfile->openDump();
    while (<$fh>) {
	#print "Parsing line: $_" if $self->{VERBOSE};
	($file, $size) = $dumpfile->lookupFileSize($_);
	if ($file) {
	    $record->{totalfiles}++;
	    $dir = dirname $file;
	    $record->{DIRS}{$dir}+=$size;
	    $record->{totalsize}+=$size;
	}
    }
    close $fh;
    $record->{totaldirs} = keys %{$record->{DIRS}};
    return $record;
}
# $record->addDir('/some/other/pfn', 9876543); # example

1;
