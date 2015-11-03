package DMWMMON::SpaceMon::NamespaceConfig;
use strict;
use warnings;
use Data::Dumper;
use File::Basename;

# Default configuration for the aggregation levels: 
my $levels_ref = {
    "/store" => 6,
};

our %params = ( DEBUG => 1,
		VERBOSE => 1,
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
    print $self->dump() if $self->{DEBUG};
    return $self;
}

sub dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }
sub readConfigFromFile {
    my $self = shift;    
    print "I am in ",__PACKAGE__,"->readConfigFromFile()\n" if $self->{VERBOSE};
}
sub lfn2pfn {
    my $self = shift;
    print "I am in ",__PACKAGE__,"->lfn2pfn()\n" if $self->{VERBOSE};
    
}
sub setLevels {
    my $self = shift;
    print "I am in ",__PACKAGE__,"->setLevels()\n" if $self->{VERBOSE};
    
}
sub getLevels {
    my $self = shift;
    print "I am in ",__PACKAGE__,"->getLevels()\n" if $self->{VERBOSE};
}

1;
