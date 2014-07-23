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

  node      PhEDEx node name.
  sename    SE name.
  protocol  A protocol name (e.g. 'srmv2', 'xrootd'...). Optional

  Either the node name or the sename may be given, but not both, that's an error

=head2 Output

  <senames>
  ...

=head3 <senames> elements

  protocol  The protocol used for contacting this SE
  sename    The hostname of the SE
  node      The PhEDEx Node Name of the site
=cut

use Data::Dumper;

sub duration { return 15 * 60; }
sub invoke { return senames(@_); }
sub senames {
  my ($core,%h) = @_;
  my (%p,$tfc,@r,%tmp,$sename,$protocol,$node,@nodes,$sql,$q);
  eval {
    %p = &validate_params(\%h,
        uc_keys => 1,
        allow => [ 'node', 'protocol', 'sename' ],
        required => [ ],
        spec => {
            node     => { using => 'node' },
            sename   => { using => 'text' },
            protocol => { using => 'protocol' },
        }
    )
  };
  if ($@) {
    return PHEDEX::Web::Util::http_error(400,$@);
  }
  # if ( $p{NODE} && $p{SENAME} ) {
  #   return PHEDEX::Web::Util::http_error(400,'Either node or sename may be given, but not both');
  # }
  # if ( !$p{NODE} && !$p{SENAME} ) {
  #   return PHEDEX::Web::Util::http_error(400,'Either node or sename must be given');
  # }

  if ( $p{NODE} ) {
    push @nodes, $p{NODE};
  } else {
    $sql = qq{ select name from t_adm_node where name like 'T%' };
    $q = PHEDEX::Web::SQL::execute_sql( $core, $sql, () );
    @nodes = map {$$_[0]} @{$q->fetchall_arrayref()};
  }

  foreach $node ( @nodes ) {
    $tfc = PHEDEX::Web::SQL::getTFC($core, ( 'node', $node ) );
#   No TFC for a user-specified node implies no node with the given name, which is an error
    if ( ! scalar(@{$tfc}) && $p{NODE} ) { return { 'senames' => undef }; }

    foreach ( @{$tfc} ) {
      if ( $_->{ELEMENT_NAME} eq 'lfn-to-pfn' ) {
        next if ( $p{PROTOCOL} && $p{PROTOCOL} ne $_->{PROTOCOL} );
        $sename = $_->{RESULT};
        next unless $sename =~ m%^[A-Za-z0-9]+://([^/]+)%;
        $sename = $1;
        $sename =~ s%:\d+$%%;
        next if ( $p{SENAME} && $p{SENAME} ne $sename );
        $tmp{$sename}{$node}{$_->{PROTOCOL}}++;
      }
    }    
  }

  foreach $sename ( keys %tmp ) {
    foreach $node ( keys %{$tmp{$sename}} ) {
      foreach $protocol ( keys %{$tmp{$sename}{$node}} ) {
        push @r, { node => $node, protocol => $protocol, sename => $sename };
      }
    }
  }

# No results for a given protocol is distinguished separately
  if ( $p{PROTOCOL} && !scalar(@r) ) {
    push @r, { protocol => $p{PROTOCOL}, 'sename' => 'undef', 'node' => undef };
  }

  return { 'senames' => \@r };
}

1;