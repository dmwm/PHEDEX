package PHEDEX::Web::API::BlockReplicaCompare;

use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Web::SQL;
use PHEDEX::Web::Spooler;

# modules that used to be provided through PHEDEX::Web::SQL

=pod

=head1 NAME

PHEDEX::Web::API::BlockReplicaCompare - Compare block replicas at two nodes and output either the differences or the matches

=head1 DESCRIPTION

Compare block replicas at two nodes and output either the differences or the matches

=head2 Options

 Required:     a, b

 a             the name of "node A" in the comparison (required)
 b             the name of "node B" in the comparison (required)
 show          which results of the comparison to output, one of 'match', 'diff' or 'neither'. any other value is an error.
               default is 'diff'.
               when using 'neither', meaning the replicas are not at either site, dataset or block is required.
 value         the value to compare on.  Can be one of:
               'files', 'bytes', 'subscribed', 'group', 'custodial'.  
               Default is 'bytes'.  Multiple values can be provided, requiring
               each of them to match.
 dataset       dataset name to restrict comparison (can be multiple)
 block         block name to restrict comparison (can be multiple)

=head2 Output

 <compare>
   <block>
     <replica_a/>
     <replica_b/>
   </block>
   ...
 </compare>

=head3 <compare> attributes

 show         'diff' or 'match', what is showing
 values       '&' separated list of values used to diff/match
 node_a       the name of node A
 node_b       the name of node B

=head3 <block> attributes

 name         block name
 id           PhEDEx block id
 files        files in block
 bytes        bytes in block
 is_open      y or n, if block is open

=head3 <replica_a> and <replica_b> attributes

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
    name => 'BLOCK',
    files => 'FILES',
    bytes => 'BYTES',
    is_open => 'IS_OPEN',
    replica_a => {
        _KEY => 'NODE_ID_A',
        node => 'NODE_A',
        node_id => 'NODE_ID_A',
        se => 'NODE_SE_A',
        files => 'NODE_FILES_A',
        bytes => 'NODE_BYTES_A',
        complete => 'COMPLETE_A',
        time_create => 'TIME_CREATE_A',
        time_update => 'TIME_UPDATE_A',
        subscribed => 'SUBSCRIBED_A',
        custodial => 'IS_CUSTODIAL_A',
        group => 'GROUP_A'
    },
    replica_b => {
        _KEY => 'NODE_ID_B',
        node => 'NODE_B',
        node_id => 'NODE_ID_B',
        se => 'NODE_SE_B',
        files => 'NODE_FILES_B',
        bytes => 'NODE_BYTES_B',
        complete => 'COMPLETE_B',
        time_create => 'TIME_CREATE_B',
        time_update => 'TIME_UPDATE_B',
        subscribed => 'SUBSCRIBED_B',
        custodial => 'IS_CUSTODIAL_B',
        group => 'GROUP_B'
    }
};

sub duration { return 5 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }
#sub invoke { return blockReplicaCompare(@_); }
#sub blockReplicaCompare
#{
#    my ($core,%h) = @_;
#
#    &checkRequired(\%h, qw / a b / );
#
#    foreach ( qw / a b show value dataset block / )
#    {
#      $h{uc $_} = delete $h{$_} if $h{$_};
#    }
#
#    # default values
#    if (!$h{SHOW})
#    {
#        $h{SHOW} = 'diff';
#    }
#    elsif ($h{SHOW} ne 'match' && $h{SHOW} ne 'neither' && $h{SHOW} ne 'diff')
#    {
#        die PHEDEX::Web::Util::http_error(400,"argument show is not one of 'match', 'diff' or 'neither'");
#    }
#
#    if (!$h{VALUE})
#    {
#        $h{VALUE} = 'bytes';
#    }
#
#    my $r;
#
#    if ($h{SHOW} eq 'neither')
#    {
#        if (!$h{DATASET} && !$h{BLOCK})
#        {
#           die PHEDEX::Web::Util::http_error(400,"'dataset' or 'bock' is required for show='neither'");
#        }
#        $r = PHEDEX::Web::SQL::getBlockReplicaCompare_Neither($core, %h);
#    }
#    else
#    {
#        $r = PHEDEX::Web::SQL::getBlockReplicaCompare($core, %h);
#    }
#
#    return { block => &PHEDEX::Core::Util::flat2tree($map, $r) };
#}

# spooling

my $sth;
my %p;
our $limit = 1000;
my @keys = ('BLOCK');

sub spool
{
    my ($core,%h) = @_;

    if (!$sth)
    {
        eval
        {
            %p = &validate_params(\%h,
                    uc_keys => 1,
                    allow => [qw( a b show value dataset block )],
                    required => [qw( a b )],
                    spec =>
                    {
                        a => { using => 'node' },
                        b => { using => 'node' },
                        show => { regex => qr/^match$|^diff$|^neither$/ },
                        value => { regex => qr/^files$|^bytes$|^subscribed$|^group$|^custodial$/ },
                        dataset => { using => 'dataset', nultiple => 1 },
                        block => { using => 'block', multiple => 1 }
                    }
            );
        };
        if ($@)
        {
            return PHEDEX::Web::Util::http_error(400,$@);
        }
        # default values
        if (!$p{SHOW})
        {
            $p{SHOW} = 'diff';
        }
        elsif ($p{SHOW} ne 'match' && $p{SHOW} ne 'neither' && $p{SHOW} ne 'diff')
        {
            return PHEDEX::Web::Util::http_error(400,"argument show is not one of 'match', 'diff' or 'neither'");
        }
    
        if (!$p{VALUE})
        {
            $p{VALUE} = 'bytes';
        }
    
        $p{'__spool__'} = 1;

        if ($p{SHOW} eq 'neither')
        {
            if (!$p{DATASET} && !$p{BLOCK})
            {
               return PHEDEX::Web::Util::http_error(400,"'dataset' or 'bock' is required for show='neither'");
            }
            $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getBlockReplicaCompare_Neither($core, %p), $limit, @keys);
        }
        else
        {
            $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getBlockReplicaCompare($core, %p), $limit, @keys);
        }
    }

    my $r = $sth->spool();
    if ($r)
    {
        return { block => &PHEDEX::Core::Util::flat2tree($map, $r) };
    }
    else
    {
        $sth = undef;
        %p = ();
        return $r;
    }
}

1;
