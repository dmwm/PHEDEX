package PHEDEX::Core::Formats; 
use base 'Exporter';

# String formatting and validation utilities

use strict; 
use warnings;

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

sub parseChecksums
{
    my ($checksums) = @_;
    return undef unless $checksums;

    my @types = qw(cksum adler32);
    my $result = {};
    foreach my $c ( split /,/, $checksums ) {
	my ($kind, $value) = split /:/, $c;
	die "bad format for checksums string '$checksums'\n" unless ($kind && $value);
	die "checksum '$kind' is not valid\n" unless (grep $kind eq $_, @types);
	$result{$kind} = $value;
    }
    return undef unless %$result;
    return $result;
}

1;
