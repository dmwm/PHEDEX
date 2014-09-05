package DMWMMON::SpaceMon::StorageDumpTXT;
use strict;
use warnings;
use Data::Dumper;
use base 'DMWMMON::SpaceMon::StorageDump';
 
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);
#my %params = (
#	      DEBUG => 1,
#	      VERBOSE => 1,
#);
#my %args = (@_);
#map { $self->{$_} = $args{$_} || $params{$_} } keys %params;
    print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};
    bless $self, $class;
# FR: validate record parameters

    return $self;
}

1;
