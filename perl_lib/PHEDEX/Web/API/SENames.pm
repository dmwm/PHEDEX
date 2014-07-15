package PHEDEX::Web::API::SENames;
use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Web::SQL;

=pod

=head1 NAME

PHEDEX::Web::API::SENames - Get SE names from the trivial file catalog

=head1 DESCRIPTION

Get the SE names listed in the TFC for a given site

=head2 Options

  node      PhEDEx node name. Required
  protocol  A protocol name (e.g. 'srmv2', 'xrootd'...). Optional

=head2 Output

  <senames>
  ...

=head3 <senames> elements

  protocol  The protocol used for contacting this SE
  sename    The hostname of the SE

=cut

use Data::Dumper;

sub duration { return 15 * 60; }
sub invoke { return senames(@_); }
sub senames {
  my ($core,%h) = @_;
  my (%p,$tfc,$r,$sename);
  eval {
    %p = &validate_params(\%h,
        uc_keys => 1,
        allow => [ 'node', 'protocol' ],
        required => [ 'node' ],
        spec => {
            node     => { using => 'node' },
            protocol => { using => 'protocol' },
        }
    )
  };
  if ($@) {
    return PHEDEX::Web::Util::http_error(400,'Blardghle! ' . $@);
  }
  $tfc = PHEDEX::Web::SQL::getTFC($core, %p);
  foreach ( @{$tfc} ) {
    if ( $_->{ELEMENT_NAME} eq 'lfn-to-pfn' ) {
      next if ( $p{PROTOCOL} && $p{PROTOCOL} ne $_->{PROTOCOL} );
      $sename = $_->{RESULT};
      next unless $sename =~ m%^[A-Za-z0-9]+://([^/]+)%;
      $sename = $1;
      $sename =~ s%:\d+$%%;
      push @{$r}, { protocol => $_->{PROTOCOL}, sename => $sename };
    }
  }

  return { 'senames' => $r };
}

1;