package PHEDEX::Web::API::Nodes;
use warnings;
use strict;
use PHEDEX::Web::SQL;

=pod

=head1 NAME

PHEDEX::Web::API::Nodes - list of nodes

=head1 DESCRIPTION

A simple dump of PhEDEx nodes.

=head2 Options

 node     PhEDex node names to filter on, can be multiple (*)
 noempty  filter out nodes which do not host any data

 (*) See the rules of multi-value filters in the Core module

=head2 Output

  <node/>
  ...

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
    my ($core,%h) = @_;
    return { node => PHEDEX::Web::SQL::getNodes($core,%h) };
}

1;
