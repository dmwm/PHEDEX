package DMWMMON::SpaceMon::Aggregate;
use strict;
use warnings;
use Data::Dumper;
 
sub new
{
my $proto = shift;
my $class = ref($proto) || $proto;
my %params = (
	      DEBUG => 1,
	      VERBOSE => 1,
);
my %args = (@_);
map { $self->{$_} = $args{$_} || $params{$_} } keys %params;
print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
bless $self, $class;
return $self;
}

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
