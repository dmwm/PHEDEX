package PHEDEX::File::Download::Circuits::Helpers::GenericFunctions;

use strict;
use warnings;

use Scalar::Util qw(blessed);

use base 'Exporter';
our @EXPORT = qw(compareResource);

sub compareResource {
    my ($object1, $object2) = @_;

    # Not equal if one's defined and the other isn't
    return 0 if (!defined $object1 == defined $object2);
    # Equal if both aren't defined
    return 1 if (!defined $object1 && !defined $object2);

    my ($dref1, $dref2) = (ref($object1), ref($object2));
    # Not equal if referenced types don't match
    return 0 if $dref1 ne $dref2;

    # Return simple comparison for variables passed by values
    return $object1 eq $object2 if ($dref1 eq '');

    if ($dref1 eq 'SCALAR' || $dref1 eq 'REF') {
        return &compareResource(${$object1}, ${$object2});
    } elsif ($dref1 eq 'ARRAY'){
        # Not equal if array size differs
        return 0 if ($#{$object1} != $#{$object1});
        # Go through all the items - order counts!
        for my $i (0 .. @{$object1}) {
            return 0 if ! &compareResource($object1->[$i], $object2->[$i]);
        }
    } elsif ($dref1 eq 'HASH' || defined blessed($object1)) {
        # Not equal if they don't have the same number of keys
        return 0 if (scalar keys (%{$object1}) != scalar keys (%{$object2}));
        # Go through all the items
        foreach my $key (keys %{$object1}) {
            return 0 if ! &compareResource($object1->{$key}, $object2->{$key});
        }
    }

    # Equal, if we get to here
    return 1;
}