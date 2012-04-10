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
use PHEDEX::Web::Util;

sub duration { return 12 * 3600; }
sub invoke { return agents(@_); }

sub agents
{
    my ($core, %h) = @_;

    my %p;
    eval
    {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [ 'group' ],
                spec =>
                {
                    group => { using => 'text', multiple => 1 }
                }
        );
    };
    if ($@)
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }

    my $r = PHEDEX::Web::SQL::getGroups($core, %p);
    return { group => $r };
}

1;
