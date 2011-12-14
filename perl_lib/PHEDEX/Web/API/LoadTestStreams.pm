package PHEDEX::Web::API::LoadTestStreams;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::LoadTestStreams - display LoadTest streams and their parameters

=head1 DESCRIPTION

Display LoadTest streams and their parameters

=head2 Options

  required inputs: none
  optional inputs: (as filters)

  node             node name, could be multiple
  se               storage element name, could be multiple
  from_dataset     name of the source dataset
  to_dataset       name of the destination
  create_since     created since this time
  update_since     updated since this time
  inject_since     injected since this time

=head2 Output

  <node>
    <loadtest>
      <from_dataset/>
      <to_dataset/>
    </loadtest>
    ...
  </node>
  ...

=head3 <node> attributes

  id              node id
  name            node name
  se              storage element

=head3 <loadtest> attributes

  is_active       y or n, whether the stream is active
  dataset_blocks  maximum number of blocks in the to_dataset
  close_dataset   whether to close the to_dataset when finished
  block_files     number of files to put in blocks
  close_blocks    whether to close blocks when block_files is
                  reached
  rate            rate (bytes/s) to inject new files
  inject_now      number of files to inject next cycle
  time_create     time the stream was created
  time_update     time the stream was updated
  time_inject     last time files were injected for this stream
  throttle_node   node to throttle injections by; typically the
                  destination node of the stream.  May be null.

=head3 <from_dataset>, <to_dataset> attributes

  id              dataset id
  name            dataset name
  is_open         y or n, whether the dataset is open

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use PHEDEX::Web::Util;

my $map = {
    _KEY => 'NODE_ID',
    node => 'NODE_NAME',
    id => 'NODE_ID',
    se => 'NODE_SE',
    loadtest => {
        _KEY => 'FROM_ID+TO_ID',
        is_active => 'IS_ACTIVE',
        dataset_blocks => 'DATASET_BLOCKS',
        close_dataset => 'DATASET_CLOSE',
        block_files => 'BLOCK_FILES',
        close_block => 'BLOCK_CLOSE',
        rate => 'RATE',
        inject_now => 'INJECT_NOW',
        time_create => 'TIME_CREATE',
        time_update => 'TIME_UPDATE',
        time_inject => 'TIME_INJECT',
        throttle_node => 'THROTTLE_NODE',
        from_dataset => {
            _KEY => 'FROM_ID',
            id => 'FROM_ID',
            name => 'FROM_NAME',
            is_open => 'FROM_IS_OPEN'
        },
        to_dataset => {
            _KEY => 'TO_ID',
            id => 'TO_ID',
            name => 'TO_NAME',
            is_open => 'TO_IS_OPEN'
        }
    }
};

sub duration { return 60 * 60; }
sub invoke { return loadteststreams(@_); }

sub loadteststreams
{
    my ($core, %h) = @_;
    my %p;
    eval
    {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [ qw / node se from_dataset to_dataset create_since update_since inject_since / ],
                spec =>
                {
                     node         => { using => 'node', multiple => 1 },
                     se           => { using => 'text', multiple => 1 },
                     from_dataset => { using => 'dataset', multiple => 1 },
                     to_dataset   => { using => 'dataset', multiple => 1 },
                     create_since => { using => 'time' },
                     update_since => { using => 'time' },
                     inject_since => { using => 'time' }
                }
        );
    };
    if ($@)
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }

    my $r = PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getLoadTestStreams($core, %p));

    return { node => $r };
}

1;
