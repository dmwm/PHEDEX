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
		  DUMPFILE => undef,
		  TIMESTAMP => undef,
		  );
    my %args = (@_);
    my $valid=0;
    map { if (defined $args{$_}) {$self->{$_} = $args{$_}} else { $self->{$_} = $params{$_}} } keys %params;
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;
    return $self;
}

sub validate {
    my $self = shift;
    print "I am in ",__PACKAGE__,"->validate()\n" if $self->{VERBOSE};
    print $self->dump();
    print "Exiting ",__PACKAGE__,"->validate()\n" if $self->{VERBOSE};
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
