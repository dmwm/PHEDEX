package PHEDEX::Web::API::BlockReplicas;
use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Web::SQL;

# modules that used to be provided through PHEDEX::Web::SQL

=pod

=head1 NAME

PHEDEX::Web::API::BlockReplicas - block replicas, the reason for PhEDEx!

=head1 DESCRIPTION

Return block replicas known to PhEDEx.

=head2 Options

 block          block name, can be multiple (*)
 node           node name, can be multiple (*)
 se             storage element name, can be multiple (*)
 update_since  unix timestamp, only return replicas updated since this
                time
 create_since   unix timestamp, only return replicas created since this
                time
 complete       y or n, whether or not to require complete or incomplete
                blocks. Default is to return either
 subscribed     y or n, filter for subscription. default is to return either.
 custodial      y or n. filter for custodial responsibility.  default is
                to return either.
 group          group name.  default is to return replicas for any group.


 (*) See the rules of multi-value filters in the Core module

=head2 Output

  <block>
     <replica/>
     <replica/>
      ...
  </block>
   ...

where <block> represents a block of files and <replica> represents a
copy of that block at some node.  An empty response means that no
block replicas exist for the given options.

=head3 <block> attributes

 name     block name
 id       PhEDEx block id
 files    files in block
 bytes    bytes in block
 is_open  y or n, if block is open

=head3 <replica> attributes

 node         PhEDEx node name
 node_id      PhEDEx node id
 se           storage element name
 files        files at node
 bytes        bytes of block replica at node
 complete     y or n, if complete
 time_create  unix timestamp of creation
 time_update  unix timestamp of last update
 subscribed   y or n, if subscribed
 custodial    y or n, if custodial
 group        group the replica is allocated for, can be undefined

=cut

my $map = {
    _KEY => 'BLOCK_ID',
    id => 'BLOCK_ID',
    name => 'BLOCK_NAME',
    files => 'BLOCK_FILES',
    bytes => 'BLOCK_BYTES',
    is_open => 'IS_OPEN',
    replica => {
        _KEY => 'NODE_ID',
        node_id => 'NODE_ID',
        node => 'NODE_NAME',
        se => 'SE_NAME',
        files => 'REPLICA_FILES',
        bytes => 'REPLICA_BYTES',
        time_create => 'REPLICA_CREATE',
        time_update => 'REPLICA_UPDATE',
        complete => 'REPLICA_COMPLETE',
        subscribed => 'SUBSCRIBED',
        custodial => 'IS_CUSTODIAL',
        group => 'USER_GROUP'
    }
};

sub duration { return 5 * 60; }
sub invoke { return blockReplicas(@_); }
sub blockReplicas
{
    my ($core,%h) = @_;

    foreach ( qw / block node se create_since update_since complete custodial subscribed group / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }
    my $r = PHEDEX::Web::SQL::getBlockReplicas($core, %h);

    return { block => &PHEDEX::Core::Util::flat2tree($map, $r) };
}

# spooling

my $last = undef;
my $sth;
my $limit = 1000;
my @keys = ('BLOCK_ID');
my $EndOfData = undef;

sub spool
{
    my ($core, %h) = @_;
    foreach ( qw / block node se create_since update_since complete custodial subscribed group / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }
    $h{'__spool__'} = 1;

    my $r;
    my $data;
    my $count = 0;

    $sth = PHEDEX::Web::SQL::getBlockReplicas($core, %h) if !$sth;
    $r = PHEDEX::Web::Util::spool($sth, $limit, @keys);
    if ($r)
    {
        return { block => &PHEDEX::Core::Util::flat2tree($map, $r) };
    }
    else
    {
        return $r;
    }
}

1;
