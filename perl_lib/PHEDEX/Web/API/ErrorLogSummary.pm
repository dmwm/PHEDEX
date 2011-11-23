package PHEDEX::Web::API::ErrorLogSummary;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::ErrorLogSummary - which blocks and files have logged errors

=head1 DESCRIPTION

Serves a list of blocks and files which have errors logged in TMDB, per link.
Note that PhEDEx only stores the last 100 errors per link, so more
errors may have occurred then indicated by this API call.

=head2 Options

 required inputs: none
 optional inputs: (as filters) from, to, block, lfn

  from             name of the source node, could be multiple
  to               name of the destination node, could be multiple
  block            block name
  dataset          dataset name
  lfn              logical file name

=head3 Output

  <link>
    <block>
      <file/>
      ...
    </block>
    ...
  </link>
  ...

=head3 <link> elements

  from             name of the source node
  from_id          id of the source node
  to               name of the destination node
  to_id            id of the destination node
  from_se          se of the source node
  to_se            se of the destination node

=head3 <block> elements

  name             block name
  id               block id
  num_errors       number of errors

=head3 <file> elements

  name             file name
  id               file id
  bytes            file length
  checksum         checksum
  num_errors       number of errors

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;
use PHEDEX::Web::Spooler;

my $map = {
    _KEY => 'FROM+TO',
    from => 'FROM',
    to => 'TO',
    from_id => 'FROM_ID',
    to_id => 'TO_ID',
    from_se => 'FROM_SE',
    to_se => 'TO_SE',
    block => {
        _KEY => 'BLOCK_ID',
        name => 'BLOCK_NAME',
        id => 'BLOCK_ID',
        file => {
            _KEY => 'FILE_ID',
            name => 'FILE_NAME',
            id => 'FILE_ID',
            checksum => 'CHECKSUM',
            size => 'FILE_SIZE',
            num_errors => 'NUM_ERRORS'
        }
    }
};

sub duration { return 60 * 60; }
sub invoke { die "'invoke' is deprecated for this API. Use the 'spool' method instead\n"; }
#sub invoke { return errorlogsummary(@_); }

#sub errorlogsummary
#{
#    my ($core, %h) = @_;
#
#    # convert parameter keys to upper case
#    foreach ( qw / from to block dataset lfn / )
#    {
#      $h{uc $_} = delete $h{$_} if $h{$_};
#    }
#
#    my $r = PHEDEX::Web::SQL::getErrorLogSummary($core, %h);
#    return { link => &PHEDEX::Core::Util::flat2tree($map, $r)};
#}

# spooling

my $sth;
our $limit = 1000;
my @keys = ('FROM', 'TO');
my %p;

sub spool
{
    my ($core, %h) = @_;

    if (!$sth)
    {
        eval
        {
            %p = &validate_params(\%h,
                    uc_keys => 1,
                    allow => [ qw / from to block dataset lfn / ],
                    spec =>
                    {
                        from    => { using => 'node', multiple => 1 },
                        to      => { using => 'node', multiple => 1 },
                        block   => { using => 'block_*', multiple => 1 },
                        dataset => { using => 'dataset', multiple => 1 },
                        lfn     => { using => 'lfn', multiple => 1 }
                    }
            );
        };
        if ($@)
        {
            return PHEDEX::Web::Util::http_error(400,$@);
        }
        $p{'__spool__'} = 1;
        $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getErrorLogSummary($core, %p), $limit, @keys);
    }

    my $r = $sth->spool();
    if ($r)
    {
        my $r1 = &PHEDEX::Core::Util::flat2tree($map, $r);
        foreach my $link (@{$r1})
        {
            my $link_errors = 0;
            foreach my $block (@{$link->{'block'}})
            {
                my $block_errors = 0;
                foreach my $file (@{$block->{'file'}})
                {
                    $block_errors += $file->{'num_errors'};
                }
                $block->{'num_errors'} = $block_errors;
                $link_errors += $block_errors;
            } 
            $link->{'num_errors'} = $link_errors;
        }
        return { link => $r1 };
    }
    else
    {
        $sth = undef;
        return $r;
    }
}

1;
