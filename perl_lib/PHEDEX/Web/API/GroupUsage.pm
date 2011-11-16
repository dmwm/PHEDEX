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
use PHEDEX::Core::Util;
use PHEDEX::Web::Util;

my $map = {
    _KEY => 'ID',
    id => 'ID',
    name => 'NODE',
    se => 'SE_NAME',
    group => {
        _KEY => 'GID',
        id => 'GID',
        name => 'USER_GROUP',
        node_files => 'NODE_FILES',
        node_bytes => 'NODE_BYTES',
        dest_files => 'DEST_FILES',
        dest_bytes => 'DEST_BYTES'
    }
};

sub duration { return 60 * 60; }
sub invoke { return groupusage(@_); }

sub groupusage
{
    my ($core, %h) = @_;
    my %p;
    eval
    {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [ qw( node group se ) ],
                spec =>
                {
                    node => { using => 'node', multiple => 1 },
                    group => { using => 'text', multiple => 1 },
                    se => { using => 'text', multiple => 1 },
                }
        );
    };
    if ($@)
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }

    my $r = PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getGroupUsage($core, %p));
    return { node => $r };
}

1;
