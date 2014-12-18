package DMWMMON::SpaceMon::Record;
use strict;
use warnings;
use Data::Dumper;
use Test::More;

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = (
		  DEBUG => 1,
		  VERBOSE => 1,
		  NODE => undef,
		  TIMESTAMP => undef,
		  DIRS => {},
		  );
    my %args = (@_);
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    map { $self->{$_} = $args{$_} || $params{$_} } keys %params;
    $self->{totalsize} = 0;
    $self->{totalfiles} = 0;
    $self->{totaldirs} = 0;
    bless $self, $class;
    return $self;
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub setTimeStamp
{
    my $self = shift;
    $self->{TIMESTAMP}=shift;
}
sub setNodeName
{
    my $self = shift;
    $self->{NODE}=shift;
}

sub addDir
{
    my $self = shift;
    my ($pfn, $size) = @_;
    # We could add checks here, or rely on parsing algorithm to validate the input:
    push @{$self->{DIRS}}, ($pfn, $size);
    print "Added dir: $pfn ==> $size \n" if $self-> {VERBOSE};
}

sub matches 
{
    my $self = shift;
    my $replica = shift;
    return is_deeply($self, $replica, 'Record matches');
}

1;
