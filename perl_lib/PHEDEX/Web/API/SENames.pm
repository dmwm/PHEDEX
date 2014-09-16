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

  node      PhEDEx node name (wildcards supported)
  sename    SE name (no wildcards)
  protocol  A protocol name (e.g. 'srmv2', 'xrootd'...). Optional, no wildcards

=head2 Output

  <senames>
  ...

=head3 <senames> elements

  protocol  The protocol used for contacting this SE
  sename    The hostname of the SE
  node      The PhEDEx Node Name of the site

If a node, a protocol or an sename is given an illegal value, that field in the return value
is undefined. This is correct for an invalid node, but needs care
if both the protocol and sename are given. If they are both specified, there is no way to tell
which "doesn't match TMDB", since neither is a primary key.

I.e. the API will return undefined for the first field in which it detects the discrepancy,
but you should check other fields for correctness too, the error may be there instead.
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

  my %params;
  $sql = qq{ select name from t_adm_node where name like :node };
  if ( $p{NODE} ) {
    $p{NODE} =~ s/\*/%/g; # TW This is a kludge!
    $params{':node'} = $p{NODE};
  } else {
    $params{':node'} = 'T%';
  }
  $q = PHEDEX::Web::SQL::execute_sql( $core, $sql, %params );
  @nodes = map {$$_[0]} @{$q->fetchall_arrayref()};
# No @nodes is an error
  if ( ! scalar(@nodes) ) {
    @r = { node => undef };
    if ( $p{PROTOCOL} ) { $r[0]{'protocol'} = $p{PROTOCOL}; }
    if ( $p{SENAME} )   { $r[0]{'senames'}  = $p{SENAME}; }
    return { 'senames' => \@r };
  }

  foreach $node ( @nodes ) {
    $tfc = PHEDEX::Web::SQL::getTFC($core, ( 'node', $node ) );

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

# No sename is an error if the sename was given, even though it may be due to the protocol
  if ( $p{SENAME} && !scalar(keys %tmp) ) {
    @r = { sename => undef };
    if ( $p{PROTOCOL} ) { $r[0]{'protocol'} = $p{PROTOCOL}; }
    if ( $p{NODE} )     { $r[0]{'node'}     = $p{NODE}; }
    return { 'senames' => \@r };
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
    @r = { protocol => undef };
    if ( $p{SENAME} ) { $r[0]{'sename'} = $p{SENAME}; }
    if ( $p{NODE} )   { $r[0]{'node'}   = $p{NODE}; }
    return { 'senames' => \@r };
  }

  return { 'senames' => \@r };
}

1;
