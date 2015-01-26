package DMWMMON::SpaceMon::RecordIO;
use strict;
use warnings;
use Data::Dumper;
use DMWMMON::SpaceMon::Record;
use DMWMMON::StorageAccounting::Core;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = (
		  DEBUG => 1,
		  VERBOSE => 1,
		  );
    my %args = (@_);
    map { if (defined $args{$_}) {$self->{$_} = $args{$_}} else { $self->{$_} = $params{$_}} } keys %params;        
    
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;    
    return $self;
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub readFromFile 
{
    my $self = shift;
    my ($file,) = (@_);
    print "RecordIO reading from file: $file\n";
    my $data = do {
	if( open my $fh, '<', $file ) 
	{ local $/; <$fh> }
	else { undef }
    };    
    my $record;
    eval $data;    
    $self->{VERBOSE} && print "Record read from $file:\n", $record->dump();
    return $record;
}

sub writeToFile
{
    my $self = shift;
    my ($record, $where) = (@_);
    print "I am in ",__PACKAGE__,"->writeToFile()\n" if $self->{VERBOSE};
    print "RecordIO writing to file: $where\n";
    open (my $fh, '>', $where) or die "Could not open file '$where' $!";
    my $dd = Data::Dumper->new(
			       [ $record ],
			       [ qw(record) ]
			       );
    print $fh $dd->Dump();
    # NR: it looks like Dump above empties the dumped object, so I can't 
    # print it again into stdout
    close $fh;
}

sub upload
{    
    my $self = shift;
    my ($url, $record) = (@_);
    $url='https://cmsweb.cern.ch/dmwmmon/datasvc' unless  (defined $url);

    print "I am in ",__PACKAGE__,"->upload()\n" if $self->{VERBOSE};
    print "In RecordIO::upload: testing upload from StorageAccounting::Core.\n Record=\n", Dumper($record);
    my $result= uploadRecord($url, $ {$record} {'DIRS'});
    return $result;
}

sub show
{
    my $self = shift;
    print "I am in ",__PACKAGE__,"->show()\n" if $self->{VERBOSE};
}

1;
