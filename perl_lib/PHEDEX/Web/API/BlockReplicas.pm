package PHEDEX::Web::API::BlockReplicas;
use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Web::SQL;
use PHEDEX::Web::Spooler;

# modules that used to be provided through PHEDEX::Web::SQL

=pod

=head1 NAME

PHEDEX::Web::API::BlockReplicas - block replicas, the reason for PhEDEx!

=head1 DESCRIPTION

Return block replicas known to PhEDEx.

=head2 Options

 block          block name, can be multiple (*)
 dataset        dataset name, can be multiple (*)
 node           node name, can be multiple (*)
 se             storage element name, can be multiple (*)
 update_since   unix timestamp, only return replicas whose record was
                updated since this time
 create_since   unix timestamp, only return replicas whose record was
                created since this time. When no "dataset", "block"
                or "node" are given, create_since is default to 24 hours ago
 complete       y or n, whether or not to require complete or incomplete
                blocks. Open blocks cannot be complete.  Default is to
                return either.
 dist_complete  y or n, "distributed complete".  If y, then returns
                only block replicas for which at least one node has
                all files in the block.  If n, then returns block
                replicas for which no node has all the files in the
                block.  Open blocks cannot be dist_complete.  Default is
                to return either kind of block replica.
 subscribed     y or n, filter for subscription. default is to return either.
 custodial      y or n. filter for custodial responsibility.  default is
                to return either.
 group          group name.  default is to return replicas for any group.
 show_dataset   y or n, default n. If y, show dataset information with
                the blocks; if n, only show blocks

 (*) See the rules of multi-value filters in the Core module

=head2 Output

 when show_dataset=n

  <block>
    <replica/>
    <replica/>
      ...
  </block>
   ...

 when show_dataset=y

  <dataset>
    <block>
      <replica/>
      <replica/>
       ...
    </block>
    <block>
       ...
    </block>
     ...
  </dataset>
   ...

where <block> represents a block of files and <replica> represents a
copy of that block at some node.  An empty response means that no
block replicas exist for the given options.

=head3 <dataset> attributes (if show_dataset=y)

 name     dataset name
 id       dataset id
 files    number of files in this dataset
 bytes    number of bytes in this dataset
 is_open  y or n, if dataset is open

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
 time_create  unix timestamp of record creation
 time_update  unix timestamp of last record update
 subscribed   y or n, if subscribed
 custodial    y or n, if custodial
 group        group the replica is allocated for, can be undefined

=head2 Caveats

=head3 Timestamps

Timestamps returned in this API are not suitable for calculating
transfer times of block replicas.  "time_create" and "time_update"
refer to creation and updating of the _record_ in the database, not of
the actual block replica which is files on a disk.  "time_create" is
usually the approximate time the block was subscribed to the node, as
this is the first time that a record is created.  "time_update" may
increment for any number of reasons, including files from the block
being transferred to disk, files from the block having transfer
attempts, files from the block being deleted, the "group" flag
changing for this block replica.  Even for these events, the timestamp
is only accurate to about 5 minutes.  The same arguments go for the
"create_since" and "update_since" filters.

=head3 Zero-file block replicas

Block replica results may appear where there are zero files
transferred.  This is used to indicate that the block is subscribed,
though no files have been transferred yet.  Keep this in mind when
counting block replicas returned from this API.

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

my $map_d = {
    _KEY => 'DATASET_ID',
    id => 'DATASET_ID',
    name => 'DATASET_NAME',
    is_open => 'DATASET_IS_OPEN',
    block => {
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
    }
};

sub duration { return 5 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }
#sub invoke { return blockReplicas(@_); }
#sub blockReplicas
#{
#    my ($core,%h) = @_;
#
#    foreach ( qw / block dataset node se create_since update_since complete dist_complete custodial subscribed group show_dataset / )
#    {
#      $h{uc $_} = delete $h{$_} if $h{$_};
#    }
#
#    if ((not $h{BLOCK}) && (not $h{DATASET}) && (not $h{NODE}) && (not $h{CREATE_SINCE}))
#    {
#        $h{CREATE_SINCE} = "-1d";
#    }
#
#    my $r = PHEDEX::Web::SQL::getBlockReplicas($core, %h);
#
#    if ($r)
#    {
#        if ($h{SHOW_DATASET} eq 'y')
#        {
#            my $r1 = &PHEDEX::Core::Util::flat2tree($map_d, $r);
#            my @dids;
#
#            # get all dataset ids
#            foreach (@{$r1})
#            {
#                push @dids, $_->{id};
#            }
#
#            # get stats of datasets
#            my $d = PHEDEX::Web::SQL::getDatasetInfo($core, 'ID' => \@dids);
#
#            # turn it into a hash
#            my %dinfo;
#            foreach (@{$d})
#            {
#                $dinfo{$_->{ID}} = $_;
#            }
#
#            # feed stats back to dataset info
#            foreach (@{$r1})
#            {
#                $_->{bytes} = $dinfo{$_->{id}}->{BYTES};
#                $_->{files} = $dinfo{$_->{id}}->{FILES};
#            }
#            
#            return { dataset => $r1 };
#        }
#        else
#        {
#            return { block => &PHEDEX::Core::Util::flat2tree($map, $r) };
#        }
#    }
#    else
#    {
#        return { block => [] };
#    }
#}

# spooling

my $sth;
our $limit = 1000;
my @keys = ('BLOCK_ID');
my %p;

sub spool
{
    my ($core, %h) = @_;
    if (!$sth)
    {
        eval {
            %p = &validate_params(\%h,
                    uc_keys => 1,
                    allow => [qw(block dataset node se create_since update_since complete dist_complete custodial subscribed group show_dataset)],
                    spec => {
                        block => { using => 'block_*', multiple => 1 },
                        dataset => { using => 'dataset', multiple => 1 },
                        node => { using => 'node', multiple => 1 },
                        se => { using => 'text', multiple => 1 },
                        create_since => { using => 'time' },
                        update_since => { using => 'time' },
                        complete => { using => 'yesno' },
                        dis_complete => { using => 'yesno' },
                        custodial => { using => 'yesno' },
                        subscribed => { using => 'yesno' },
                        group => { using => 'text' },
                        show_dataset => { using => 'yesno' }
                    }
            );
        };

        if ($@)
        {
            return PHEDEX::Web::Util::http_error(400,$@);
        }
    
        $p{SHOW_DATASET} ||= 'n';
        if ((not $p{BLOCK}) && (not $p{DATASET}) && (not $p{NODE}) && (not $p{CREATE_SINCE}))
        {
            $p{CREATE_SINCE} = "-1d";
        }
    
        if ($p{SHOW_DATASET} eq 'y')
        {
            @keys = ('DATASET_ID');
        }
    
        $p{'__spool__'} = 1;
    }

    my $r;

    $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getBlockReplicas($core, %p), $limit, @keys) if !$sth;

    $r = $sth->spool();
    if ($r)
    {
        if ($p{SHOW_DATASET} eq 'y')
        {
            my $r1 = &PHEDEX::Core::Util::flat2tree($map_d, $r);
            my @dids;

            # get all dataset ids
            foreach (@{$r1})
            {
                push @dids, $_->{id};
            }

            # get stats of datasets
            if ($#dids > 0)
            {
                my $d = PHEDEX::Web::SQL::getDatasetInfo($core, 'ID' => \@dids);

                # turn it into a hash
                my %dinfo;
                foreach (@{$d})
                {
                    $dinfo{$_->{ID}} = $_;
                }

                # feed stats back to dataset info
                foreach (@{$r1})
                {
                    $_->{bytes} = int($dinfo{$_->{id}}->{BYTES});
                    $_->{files} = $dinfo{$_->{id}}->{FILES};
                }
            }
            
            return { dataset => $r1 };
        }
        else
        {
            return { block => &PHEDEX::Core::Util::flat2tree($map, $r) };
        }
    }
    else
    {
        $sth = undef;
        %p = ();
        return $r;
    }
}

1;
