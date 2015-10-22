package PHEDEX::File::Download::Circuits::Backend::Core::IDC;

use strict;
use warnings;

# This could very well be a simple hash...
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
            DYNES_NAME  =>      undef,
            PHEDEX_NAME =>      undef,
            IP          =>      undef,
            PORT        =>      undef,
            BANDWIDTH   =>      1000,
            MAX_LIFE    =>      6*3600,
    );

    my %args = (@_);

    #   use 'defined' instead of testing on value to allow for arguments which are set to zero.
    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = \%args;

    bless $self, $class;

    return $self;
}

1;