package DMWMMON::SpaceMon::StorageDump;
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
);
my %args = (@_);
map { $self->{$_} = $args{$_} || $params{$_} } keys %params;
print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
bless $self, $class;
# FR: validate record parameters

return $self;
}

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
