package DMWMMON::SpaceMon::FormatFactory;
use strict;
use warnings;

sub instantiate 
{
    my $class          = shift;
    my $requested_type = shift;
    my $location       = "DMWMMON/SpaceMon/Format/$requested_type.pm";
    $class             = "DMWMMON::SpaceMon::Format::$requested_type";
    require $location;
    return $class->new(@_);
}

1;
