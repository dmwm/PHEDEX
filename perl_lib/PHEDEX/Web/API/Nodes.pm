package PHEDEX::Web::API::Nodes;
use warnings;
use strict;
use PHEDEX::Core::SQL;
use PHEDEX::Web::Util;

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

sub duration{ return 12 * 3600; }
sub invoke { return nodes(@_); }
sub nodes
{
    my ($core,%h) = @_;
    my %p;
    eval {
        %p = &validate_params(\%h,
            uc_keys => 1,
            allow => [ qw/ node noempty / ],
            spec => {
                node => { using => 'node', multiple => 1 },
                noempty => { using => 'yesno' }
            });
    };
    if ( $@ )
    {
        return PHEDEX::Web::Util::http_error(400, $@);
    }

    return { node => PHEDEX::Core::SQL::getNodes($core,%p) };
}

1;
