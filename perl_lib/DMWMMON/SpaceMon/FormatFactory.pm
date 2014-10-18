package DMWMMON::SpaceMon::FormatFactory;
use strict;
use warnings;
use Data::Dumper;

sub instantiate 
{
    my $class = shift;
    my %params = @_;
    my $h = \%params;
    if (defined $h->{FORMAT}){
	print "FORMAT: $h->{FORMAT}\n" if $h->{VERBOSE};
    } elsif (defined $h->{DUMPFILE} ) {
	die "Checking format of file: $h->{DUMPFILE}\n";
    } else {
	die "ERROR: Format not defined \n";
    }

    my $location       = "DMWMMON/SpaceMon/Format/" . $h->{FORMAT} . ".pm";
    $class             = "DMWMMON::SpaceMon::Format::" . $h->{FORMAT};
    require $location;
    return $class->new(%{$h});
}

1;
