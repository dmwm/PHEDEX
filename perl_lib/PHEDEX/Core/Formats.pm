package PHEDEX::Core::Formats; use strict; use warnings; use base 'Exporter';

# Replacement for UtilsMisc.  Renamed to "Formats".  This module
# should contain string-formatting code

our @EXPORT = qw(sizeValue);

sub sizeValue
{
    my ($value) = @_;
    if ($value =~ /^(\d+)([kMGT])$/)
    {
        my %scale = ('k' => 1024, 'M' => 1024**2, 'G' => 1024**3, 'T' => 1024**4);
        $value = $1 * $scale{$2};
    }
    return $value;
}

1;
