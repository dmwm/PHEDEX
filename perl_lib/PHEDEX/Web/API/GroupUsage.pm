package PHEDEX::Web::API::GroupUsage;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::GroupUsage - storage statistics by group

=head1 DESCRIPTION

Serves storage statistics node per group.

=head2 Options

 required inputs: none
 optional inputs: (as filters) node, se, group

  node             node name, could be multiple
  se               storage element name, could be multiple
  group            group name, could be multiple

=head2 Output

  <node>
    <group/>
    ...
  </node>
  ...

=head3 <node> elements

  name             node name
  id               node id
  se               storage element

=head3 <group> elements

  name             group name
  id               group id
  node_bytes       number of bytes archived on this node
  node_files       number of files archived on this node
  dest_bytes       number of approved bytes for this group
  dest_files       number of approved files for this group

=cut


use PHEDEX::Web::SQL;

sub duration { return 60 * 60; }
sub invoke { return groupusage(@_); }

sub groupusage
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / node group se / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getGroupUsage($core, %h);
    return { node => $r };
}

1;
