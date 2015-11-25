package PHEDEX::File::Download::Circuits::Backend::NSI::Native::ConnectionService;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %params = (
    );

    my %args = (@_);

    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);
    
    bless $self, $class;
    return $self;
}

sub reserve {
    my ($self, $connectionID) = @_;
}

sub commit {
    my ($self, $connectionID) = @_;
}

sub abort {
    my ($self, $connectionID) = @_;
}

sub provision {
    my ($self, $connectionID) = @_;
}

sub release {
    my ($self, $connectionID) = @_;
}

sub terminate {
    my ($self, $connectionID) = @_;
}

1;