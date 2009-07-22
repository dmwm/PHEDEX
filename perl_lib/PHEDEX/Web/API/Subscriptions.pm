package PHEDEX::Web::API::Subscriptions;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Subscriptions -- show which subscriptions exist and their parameters.

=head1 DESCRIPTION

Show existing subscriptions and their parameters.

=head2 Options

  dataset          dataset name (wildcards)
  block            block name (wildcards)
  node             node name (wildcards)
  se               storage element
  create_since     timestamp. only subscriptions created after.
  update_since     timestamp. only subscriptions updated after.
  request request  number which created the subscription.
  custodial        y or n to filter custodial/non subscriptions.
                   default is null (either)
  group            group name filter 
  priority         priority, one of "low", "normal" and "high"
  move             y (move) or n (replica)

=head2 Output

  <dataset>
    <subscription/>
    <block>
      <subscription/>
    </block>
  </dataset> 

  Dataset-level subscriptions will have <subscription> as a child of <dataset>
  Block-level subscriptions will have <subscription> as a child of <block> 

=head3 <subscription> attributes:

  node             PhEDEx node name which is subscribed to the parent
  node_id          PhEDEx node id
  se               storage element name
  level            the subscription level, 'dataset' or 'block'
  request          request ID
  priority         priority (high, normal, low)
  move             is move? y or n
  custodial        is custodial? y or n
  group            user group
  time_create      when the subscription was created
  suspended        is suspended? y or n
  suspend_until    time suspension expires 

=head3 <dataset> attributes:

  name             dataset name
  id               PhEDEx dataset id
  files            files in dataset
  bytes            bytes in dataset
  is_open          y or n, if dataset is open

=head3 <block> attributes:

  name             block name
  id               PhEDEx block id
  files            files in block
  bytes            bytes in block
  is_open          y or n, if block is open 

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;

# mapping format for the output
my $map = {
    _KEY => 'DATASET_ID',
    id => 'DATASET_ID',
    name => 'DATASET_NAME',
    files => 'NODE_FILES',
    bytes => 'NODE_BYTES',
    is_open => 'OPEN',
    subscription => {
        _KEY => 'REQUEST',
        level => 'LEVEL',
        node => 'NODE',
        node_id => 'NODE_ID',
        request => 'REQUEST',
        priority => 'PRIORITY',
        move => 'MOVE',
        custodial => 'CUSTODIAL',
        group => 'GROUP',
        time_created => 'TIME_CREATE',
        suspended => 'SUSPENDED',
        suspend_until => 'SUSPEND_UNTIL'
    }
};

my $map2 = {
    _KEY => 'DATASET_ID',
    id => 'DATASET_ID',
    name => 'DATASET_NAME',
    files => 'NODE_FILES',
    bytes => 'NODE_BYTES',
    is_open => 'OPEN',
    block => {
        _KEY => 'ITEM_ID',
        id => 'ITEM_ID',
        name => 'ITEM_NAME',
        files => 'FILES',
        bytes => 'BYTES',
        is_open => 'OPEN',
        subscription => {
            _KEY => 'LEVEL',
            level => 'LEVEL',
            node => 'NODE',
            node_id => 'NODE_ID',
            request => 'REQUEST',
            priority => 'PRIORITY',
            move => 'MOVE',
            custodial => 'CUSTODIAL',
            group => 'GROUP',
            time_created => 'TIME_CREATE',
            suspended => 'SUSPENDED',
            suspend_until => 'SUSPEND_UNTIL'
        }
    }
};
            

sub duration { return 60 * 60; }
sub invoke { return subscriptions(@_); }

sub subscriptions
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / dataset block node se create_since update_since request custodial group move priority / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getDataSubscriptions($core, %h);
    # separate DATASET and BLOCK
    my (@dataset, @block);
    foreach (@{$r})
    {
        if ($_->{'LEVEL'} eq 'DATASET')
        {
            push @dataset, $_;
	}
	elsif ($_->{'LEVEL'} eq 'BLOCK')
        {
            push @block, $_;
        }
    }

    my $out = {};
    foreach(@dataset)
    {
        &PHEDEX::Core::Util::build_hash($map, $_, $out);
    }
    return { dataset => &PHEDEX::Core::Util::flat2tree($map2, \@block, $out) };
    # return { subscription => $r };
}

1;
