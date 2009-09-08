package PHEDEX::Web::API::Links;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Links -- current link status

=head1 DESCRIPTION

Show current link status

=head2 Options

 required inputs: none
 optional inputs: from, to

  from             source node
  to               destination node

=head2 Output

  <link/>
  ...

=head3 <link> elements

  from             source node
  to               destination node
  from_kind        type of source node
  to_kind          type of destination node
  xso_update       source node update time
  xsi_update       destination node update time
  xso_protos       source node protocols
  xsi_protos       destination node protocols
  xso_age          time elapsed at source node
  xsi_age          time elapsed at destination node
  exists           0 or 1, if the link exists
  excluded         0 or 1, if the link is excluded
  valid            0 or 1, if the link is valid
  is_active        'y' or 'n', if the link is active
  color            status
  reason           reason for update

=cut

use PHEDEX::Web::SQL;

sub duration { return 60 * 60; }
sub invoke { return links(@_); }

sub links
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / from to status kind / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getLinks($core, %h);
    return { link => $r };
}

1;
