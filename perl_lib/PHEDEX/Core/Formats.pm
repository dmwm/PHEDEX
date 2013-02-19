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
        my %scale = ('k' => 1000, 'M' => 1000**2, 'G' => 1000**3, 'T' => 1000**4, 'P' => 1000**5);
        $value = $1 * $scale{$2};
    }
    return $value;
}

sub parseChecksums
{
    my ($checksums) = @_;
    return undef unless $checksums;

    my @types = qw(cksum adler32);
    my @fields = split /,/, $checksums;
    if (scalar @fields != 1 + scalar $checksums =~ tr/,//) {
	die "bad format for checksums string '$checksums'\n";
    }
    my $result = {};
    foreach my $c ( @fields ) {
	my ($kind, $value) = split /:/, $c;
	die "bad format for checksums string '$checksums'\n" unless ($kind && $value);
	die "checksum type '$kind' is not allowed\n" unless (grep $kind eq $_, @types);
	die "$kind value '$value' is not valid\n" unless ($value =~ /^[0-9A-Fa-f]+$/);
	die "multiple values for $kind checksum in checksums string '$checksums'\n" if exists $result->{$kind};
	$result->{$kind} = $value;
    }
    return undef unless %$result;
    return $result;
}

1;
