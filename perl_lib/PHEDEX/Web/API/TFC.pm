package PHEDEX::Web::API::TFC;
use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Web::SQL;

=pod

=head1 NAME

PHEDEX::Web::API::TFC - the trivial file catalog

=head1 DESCRIPTION

Serves the TFC published to TMDB for a given node.

=head2 Options

  node  PhEDEx node name. Required

=head2 Output

  <lfn-to-pfn>
  ...
  <pfn-to-lfn>
  ...

See TFC documentation.

=cut

sub duration { return 15 * 60; }
sub invoke { return tfc(@_); }
sub tfc
{
    my ($core,%h) = @_;
    checkRequired(\%h, 'node');
    my $r = PHEDEX::Web::SQL::getTFC($core, %h);
    return { 'storage-mapping' => { array => $r } };
}

1;
