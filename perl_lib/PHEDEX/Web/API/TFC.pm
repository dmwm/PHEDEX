package PHEDEX::Web::API::TFC;
use warnings;
use strict;
use PHEDEX::Web::Util;

=pod
=head1 NAME

PHEDEX::Web::API::TFC

=head1 DESCRIPTION

=head2 tfc

Show the TFC published to TMDB for a given node

=head3 options

  node  PhEDEx node name. Required

=head3 <lfn-to-pfn> or <pfn-to-lfn> attributes

See TFC documentation.

=cut

sub duration { return 15 * 60; }
sub invoke { return tfc(@_); }
sub tfc
{
    my ($self,$core,%h) = @_;
    checkRequired(\%h, 'node');
    my $r = PHEDEX::Web::SQL::getTFC($core, %h);
    return { array => $r };
}

1;
