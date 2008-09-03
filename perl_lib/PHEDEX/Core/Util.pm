package PHEDEX::Core::Util;

=pod
=head1 NAME

PHEDEX::Core::Util - basic utility functions that may be useful in any module

=cut

use warnings;
use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw (); # export nothing by default
our @EXPORT_OK = qw( arrayref_expand );

#-------------------------------------------------------------------------------
# Takes an array and expands all arrayrefs in the array
sub arrayref_expand
{
    my @out;
    foreach (@_) {
	if    (!ref $_)           { push @out, $_; }
	elsif (ref $_ eq 'ARRAY') { push @out, @$_; } 
	else { next; }
    }
    return @out;
}

1;
