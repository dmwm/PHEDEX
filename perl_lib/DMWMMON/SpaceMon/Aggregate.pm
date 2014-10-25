package DMWMMON::SpaceMon::Aggregate;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use DMWMMON::SpaceMon::Record;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = (
		  DEBUG => 1,
		  VERBOSE => 1,
		  LEVEL => 6,
		  # we search for this directory and count levels down from there:
		  STARTPATH => "/store/",
		  );
    my %args = (@_);
    
    map { if (defined $args{$_}) {$self->{$_} = $args{$_}} else { $self->{$_} = $params{$_}} } keys %params;        
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;
    return $self;
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub countSpace {
# Parses dump and saves results in the dumpfile object:
    my $self = shift;
    my $dumpfile = shift;
    print "I am in ",__PACKAGE__,"->countSpace()\n" if $self->{VERBOSE};
    my ($size, $file, $dir);
    my $fh = $dumpfile->openDump();
    print $dumpfile->dump();
    while (<$fh>) {
	($file, $size) = $dumpfile->lookupFileSize($_);
	if ($file) {
	    $dumpfile->{totalfiles}++;
	    $dir = dirname $file;
	    $dumpfile->{DIRS}{$dir}+=$size;
	    $dumpfile->{totalsize}+=$size;
	}
    }
    close $fh;
    $dumpfile->{totaldirs} = keys %{$dumpfile->{DIRS}};
}
 
sub createRecord {
# Does aggregation:
    my $self = shift;
    my $dumpfile = shift;
    print "I am in ",__PACKAGE__,"->createRecord()\n" if $self->{VERBOSE};
    print "Processing file $dumpfile->{DUMPFILE}\n" if $self->{VERBOSE};
    my $record= DMWMMON::SpaceMon::Record->new();
    #while (<$fh>) {
    #	#print "Parsing line: $_" if $self->{VERBOSE};
#	my @result = $dumpfile->lookupFileSize($_);
#	if (@result) {
#	    $record->addDir(@result); # example 
#	}
#    }
    #$record->addDir('/some/other/pfn', 9876543); # example 
    print $dumpfile->dump();
    return $record;    
}


1;
