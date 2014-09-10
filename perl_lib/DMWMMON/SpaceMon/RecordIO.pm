package DMWMMON::SpaceMon::RecordIO;
use strict;
use warnings;
use Data::Dumper;
use DMWMMON::SpaceMon::Record;

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
    return DMWMMON::SpaceMon::Record->new();
    
}
sub writeToFile
{
    my $self = shift;
    my ($what, $where) = (@_);
    print "I am in ",__PACKAGE__,"->writeToFile()\n" if $self->{VERBOSE};
    print "RecordIO writing to file: $where\n";
    $self->{VERBOSE} && print "Wrote a record:", $what->dump();
}

sub upload
{    
    my $self = shift;
    print "I am in ",__PACKAGE__,"->upload()\n" if $self->{VERBOSE};
    print "Dummy upload: here goes all Datasvc/UA stuff.\n";
    return 1;
}

sub show
{
    my $self = shift;
    print "I am in ",__PACKAGE__,"->show()\n" if $self->{VERBOSE};
}

1;
