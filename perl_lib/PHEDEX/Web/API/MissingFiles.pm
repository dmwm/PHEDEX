package PHEDEX::Web::API::MissingFiles;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::MissingFiles -- show files which are missing form blocks at a node

=head1 DESCRIPTION

Show files which are missing from blocks at a node.

=head2 Options

  block            block name (wildcards), required.
  node             node name (wildcards).
  se               storage element.
  subscribed       y or n. whether the block is subscribed to the node or not
                   default is null (either)
  custodial        y or n. filter for custodial responsibility,
                   default is to return either.
  group            group name.
                   default is to return missing blocks for any group.
  lfn              logical file name.

=head2 Output

  <block>
    <file>
      <missing/>
      ...
    </file>
    ...
  </block>
  ... 

=head3 <block> attributes

  name             block name
  id               PhEDEx block id
  files            number of files in block
  bytes            number of bytes in block
  is_open          y or n, if block is open 

=head3 <file> attributes
  
  name             logical file name
  id               PhEDEx file id
  bytes            number of bytes in the file
  checksum         checksum of the file
  origin_node      node name of the place of origin for this file
  time_create      time that this file was born in PhEDEx

=head3 <missing> attributes
  
  node_name        node name which is missing the file
  node_id          node id which is missing the file
  se               SE which is missing the file
  subscribed       y or n. whether the file is subscribed to the node or not
  custodial        y or n. if custodial
  group            group the file is for 

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;

# mapping format for the output
my $map = {
    _KEY => 'BLOCK_ID',
    id => 'BLOCK_ID',
    name => 'BLOCK_NAME',
    files => 'BLOCK_FILES',
    bytes => 'BLOCK_BYTES',
    is_open => 'IS_OPEN',
    file => {
        _KEY => 'FILE_ID',
        id => 'FILE_ID',
        name => 'LOGICAL_NAME',
        bytes => 'FILESIZE',
        checksum => 'CHECKSUM',
        origin_node => 'ORIGIN_NODE',
        time_create => 'TIME_CREATE',
        missing => {
            _KEY => 'NODE_NAME+FILE_ID',
            node_name => 'NODE_NAME',
            node_id => 'NODE_ID',
            se => 'SE_NAME',
            subscribed => 'SUBSCRIBED',
            custodial => 'IS_CUSTODIAL',
            group => 'USER_GROUP'
        }
    }
};


sub duration { return 60 * 60; }
sub invoke { return missingfiles(@_); }

sub missingfiles
{
    my ($core, %h) = @_;

    &checkRequired(\%h, 'block');

    # convert parameter keys to upper case
    foreach ( qw / block node se subscribed custodial group lfn / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getMissingFIles($core, %h);
    return { block => &PHEDEX::Core::Util::flat2tree($map, $r) };
    # return { subscription => $r };
}

1;
