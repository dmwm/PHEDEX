package DMWMMON::SpaceMon::Record;
use strict;
use warnings;
use Data::Dumper;

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
map { $self->{$_} = $args{$_} || $params{$_} } keys %params;
bless $self, $class;
return $self;
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub matches 
{
    my $self = shift;
    my $replica = shift;
    # assume they match:
    return 1;
}

1;
