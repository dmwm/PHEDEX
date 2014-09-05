package DMWMMON::SpaceMon::Aggregate;
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

sub createRecord
{
    my $self = shift;
    $self->{RECORD}= DMWMMON::SpaceMon::Record->new();
}
1;
