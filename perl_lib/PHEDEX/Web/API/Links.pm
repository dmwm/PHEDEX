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

  from                  source node
  to                    destination node
  status                link status (one of: ok, deactivated, to_excluded,
                       from_excluded, to_down, from_down) 
  kind                 type of link (one of: WAN, Local, Staging, Migration)

=head2 Output

  <link/>
  ...

=head3 <link> elements

  from                  source node
  to                    destination node
  from_kind             type of source node
  to_kind               type of destination node
  from_agent_update     source node update time
  to_agent_update       destination node update time
  from_agent_protocols  source node protocols
  to_agent_protocols    destination node protocols
  from_agent_age        time elapsed at source node
  to_agent_age          time elapsed at destination node
  status                link status (one of: ok, deactivated, to_excluded,
                        from_excluded, to_down, from_down) 
  kind                  type of link (one of: WAN, Local, Staging, Migration)

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
