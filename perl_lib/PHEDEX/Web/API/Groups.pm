package PHEDEX::Web::API::Groups;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Groups -- show groups known to PhEDEx

=head1 DESCRIPTION

Return groups known to PhEDEx.

=head2 Options

 required inputs: none
 optional inputs: (as filters) group

  group            name of the group

=head2 Output

  <group/>
  ...

=head3 <group> elements

  name             group name
  id               group id

=cut


use PHEDEX::Web::SQL;

sub duration { return 60 * 60; }
sub invoke { return agents(@_); }

sub agents
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / group / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getGroups($core, %h);
    return { group => $r };
}

1;
