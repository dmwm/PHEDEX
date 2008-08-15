package PHEDEX::Web::API::Nodes;
use warnings;
use strict;
use PHEDEX::Web::Util;

=pod
=head1 NAME

PHEDEX::Web::API::Nodes - fetch, format, and return PhEDEx data

=head1 DESCRIPTION

=head2 nodes

A simple dump of PhEDEx nodes.

=head3 options

 node     PhEDex node names to filter on, can be multiple (*)
 noempty  filter out nodes which do not host any data

 (*) See the rules of multi-value filters above

=head3 <node> attributes

 name        PhEDEx node name
 se          storage element
 kind        node type, e.g. 'Disk' or 'MSS'
 technology  node technology, e.g. 'Castor'
 id          node id

=cut

sub duration{ return 60 * 60; }
sub invoke { return nodes(@_); }
sub nodes
{
    my ($self,$core,%h) = @_;
    return { Nodes => PHEDEX::Web::SQL::getNodes($core,%h) };
}

1;
