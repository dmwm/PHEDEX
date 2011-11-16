package PHEDEX::Web::API::BlockReplicaSummary;
use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Web::SQL;
use PHEDEX::Web::Spooler;

# modules that used to be provided through PHEDEX::Web::SQL

=pod

=head1 NAME

PHEDEX::Web::API::BlockReplicaSummary - simple view of block replicas

=head1 DESCRIPTION

Return block replicas known to PhEDEx.

=head2 Options

 block          block name, can be multiple (*)
 dataset        dataset name, can be multiple (*)
 node           node name, can be multiple (*)
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

=head3 <replica> attributes

 node         PhEDEx node name
 complete     y or n, if complete

=cut

my $map = {
    _KEY => 'BLOCK_ID',
    name => 'BLOCK_NAME',
    replica => {
        _KEY => 'NODE_ID',
        node => 'NODE_NAME',
        complete => 'REPLICA_COMPLETE'
    }
};

sub duration { return 5 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }
#sub invoke { return blockReplicas(@_); }
#sub blockReplicas
#{
#    my ($core,%h) = @_;
#
#    foreach ( qw / block dataset node se create_since update_since complete dist_complete custodial subscribed / )
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
#    return { block => &PHEDEX::Core::Util::flat2tree($map, $r) };
#}

# spooling

my $sth;
my %p;
our $limit = 1000;
my @keys = ('BLOCK_ID');

sub spool
{
    my ($core, %h) = @_;

    if (!$sth)
    {
        eval
        {
            %p = &validate_params(\%h,
                    uc_keys => 1,
                    allow => [qw( block dataset node se create_since update_since complete dist_complete custodial subscribed )],
                    spec =>
                    {
                        block => { using => 'block_*', multiple => 1 },
                        dataset => { using => 'dataset', multiple => 1 },
                        node => { using => 'node', multiple => 1 },
                        complete => { using => 'yesno' },
                        se => { using => 'text', multiple => 1 },
                        create_since => { using => 'time' },
                        update_since => { using => 'time' },
                        dist_complete => { using => 'yesno' },
                        custodial     => { using => 'yesno' },
                        subscribed    => { using => 'yesno' }
                     }
            );
        };

        if ($@)
        {
            return PHEDEX::Web::Util::http_error(400,$@);
        }

        if ((not $p{BLOCK}) && (not $p{DATASET}) && (not $p{NODE}) && (not $p{CREATE_SINCE}))
        {
            $p{CREATE_SINCE} = "-1d";
        }

        $p{'__spool__'} = 1;

        $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getBlockReplicas($core, %p), $limit, @keys);
    }

    my $r;

    $r = $sth->spool();
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
