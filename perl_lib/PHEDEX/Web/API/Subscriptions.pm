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
  create_since     timestamp. only subscriptions created after.*
  request          request number which created the subscription.
  custodial        y or n to filter custodial/non subscriptions.
                   default is null (either)
  group            group name filter 
  priority         priority, one of "low", "normal" and "high"
  move             y (move) or n (replica)
  suspended        y or n, default is either

  collapse         y or n. default n. If y, do not show block level
                   subscriptions of a dataset if it was subscribed at
                   dataset level.

  * when no arguments are specified, except "collapse", default create_since is set to 1 day ago

=head2 Output

  <dataset>
    <subscription/>
    ...
    <block>
      <subscription/>
    </block>
    ...
  </dataset> 

  Dataset-level subscriptions will have <subscription> as a child of <dataset>
  Block-level subscriptions will have <subscription> as a child of <block> 

=head3 <subscription> attributes:

  node             PhEDEx node name which is subscribed to the parent
  node_id          PhEDEx node id
  se               storage element name
  level            the subscription level, 'dataset' or 'block'
  request          request ID
  node_files       number of files at this node
  node_bytes       number of bytes at this node
  priority         priority (high, normal, low)
  move             is move? y or n
  custodial        is custodial? y or n
  group            user group
  time_create      when the subscription was created
  suspended        is suspended? y or n
  suspend_until    time suspension expires 
  percent_files    percentage of files at destination
  percent_bytes    percentage of bytes at destination

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
    is_open => 'OPEN',
    files => 'DS_FILES',
    bytes => 'DS_BYTES',
    subscription => {
        _KEY => 'NODE_ID',
        level => 'LEVEL',
        node => 'NODE',
        node_id => 'NODE_ID',
        node_files => 'NODE_FILES',
        node_bytes => 'NODE_BYTES',
        request => 'REQUEST',
        priority => 'PRIORITY',
        move => 'MOVE',
        custodial => 'CUSTODIAL',
        group => 'GROUP',
        time_create => 'TIME_CREATE',
        time_update => 'TIME_UPDATE',
        suspended => 'SUSPENDED',
        suspend_until => 'SUSPEND_UNTIL',
        percent_files => 'PERCENT_FILES'
        percent_bytes => 'PERCENT_BYTES'
    }
};

my $map2 = {
    _KEY => 'DATASET_ID',
    id => 'DATASET_ID',
    name => 'DATASET_NAME',
    is_open => 'OPEN',
    files => 'DS_FILES',
    bytes => 'DS_BYTES',
    block => {
        _KEY => 'ITEM_ID',
        id => 'ITEM_ID',
        name => 'ITEM_NAME',
        files => 'FILES',
        bytes => 'BYTES',
        is_open => 'OPEN',
        subscription => {
            _KEY => 'NODE_ID',
            level => 'LEVEL',
            node => 'NODE',
            node_id => 'NODE_ID',
            node_files => 'NODE_FILES',
            node_bytes => 'NODE_BYTES',
            request => 'REQUEST',
            priority => 'PRIORITY',
            move => 'MOVE',
            custodial => 'CUSTODIAL',
            group => 'GROUP',
            time_create => 'TIME_CREATE',
            time_update => 'TIME_UPDATE',
            suspended => 'SUSPENDED',
            suspend_until => 'SUSPEND_UNTIL',
            percent_files => 'PERCENT_FILES'
            percent_bytes => 'PERCENT_BYTES'
        }
    }
};

sub duration { return 300; }
sub invoke { return subscriptions(@_); }

sub subscriptions
{
    my ($core, %h) = @_;

    # remove collapse if it is not 'y'
    if ((exists $h{collapse}) && ($h{collapse} ne 'y'))
    {
        delete $h{collapse};
    }

    # convert parameter keys to upper case
    foreach ( qw / dataset block node se create_since request custodial group move priority suspended collapse / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    # if there is no input argument, set default "since" to 24 hours ago
    if ((scalar keys %h == 0) || (scalar keys %h == 1) && exists $h{COLLAPSE})
    {
        $h{CREATE_SINCE} = time() - 3600*24;
    }

    my $r = PHEDEX::Web::SQL::getDataSubscriptions($core, %h);
    # separate DATASET and BLOCK
    my (@dataset, @block);
    foreach (@{$r})
    {
        if ($_->{'LEVEL'} eq 'dataset')
        {
            push @dataset, $_;
	}
	elsif ($_->{'LEVEL'} eq 'block')
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
