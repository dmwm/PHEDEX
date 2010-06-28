package PHEDEX::Web::API::Deletions;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Deletions -- Show pending and recently completed deletions

=head1 DESCRIPTION

Show pending and recently completed deletions 

=head2 Options

 required inputs: none
 optional inputs: (as filters) node, block, se, request_since, complete, complete_since

  node             node name, could be multiple
  se               storage element name, could be multiple
  block            block name, allows wildcard, could be multiple
  dataset          dataset name, allows wildcard, could be multiple
  id               block id, allow multiple
  request          request id, could be multiple
  request_since    since time requested
  complete         whether completed (y or n, default is either) 
  complete_since   since time completed

=head2 Output

  <dataset>
    <block>
      <deletion/>
      ...
    </block>
    ...
  </dataset>
  ...

=head3 <dataset> attributes:

  name             dataset name
  id               PhEDEx dataset id
  files            files in dataset
  bytes            bytes in dataset
  is_open          y or n, if dataset is open 

=head3 <blcok> attributes:

  name             block name
  id               block id
  files            number of files in block
  bytes            number of size in block

=head3 <deletion> elements

  node             node name
  se               storage element name
  node_id          node id
  request          request id
  time_request     time the request was made
  time_complete    time the deletion was completed
  complete         whether the deletion was completed (y or n)

=cut


use PHEDEX::Web::SQL;
use PHEDEX::Web::Util;
use PHEDEX::Core::Util;
use PHEDEX::Web::Spooler;

sub duration { return 60 * 60; }
sub invoke { return deletionqueue(@_); }

my $map = {
    _KEY => 'DATASET_ID',
    id => 'DATASET_ID',
    name => 'DATASET',
    is_open => 'IS_OPEN',
    block => {
        _KEY => 'BLOCK_ID',
        id => 'BLOCK_ID',
        name => 'BLOCK',
        files => 'FILES',
        bytes => 'BYTES',
        deletion => {
            _KEY => 'NODE+TIME_REQUEST',
            request => 'REQUEST',
            node => 'NODE',
            se => 'SE',
            id => 'NODE_ID',
            time_request => 'TIME_REQUEST',
            time_complete => 'TIME_COMPLETE',
            complete => 'COMPLETE'
        }
    }
};


sub deletionqueue
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / node se block dataset id request request_since complete complete_since / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getDeletions($core, %h);
    my $s = &PHEDEX::Core::Util::flat2tree($map, $r);
    # now, deal with the files and bytes in the dataset
    foreach my $d (@$s)
    {
        $d->{files} = 0;
        $d->{bytes} = 0;
        foreach (@{$d->{block}})
        {
            $d->{files} += $_->{files};
            $d->{bytes} += $_->{bytes};
        }
    }
    return { dataset => $s };
}

# spooling

my $sth;
my $limit = 1000;
my @keys = ('DATASET_ID');

sub spool
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / node se block dataset id request request_since complete complete_since / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }
    $h{'__spool__'} = 1;

    $sth = PHEDEX::Web::Spooler->new(PHEDEX::Web::SQL::getDeletions($core, %h), $limit. @keys) if !$sth;

    my $r = $sth->spool();
    if ($r)
    {
        my $s = &PHEDEX::Core::Util::flat2tree($map, $r);
        # now, deal with the files and bytes in the dataset
        foreach my $d (@$s)
        {
            $d->{files} = 0;
            $d->{bytes} = 0;
            foreach (@{$d->{block}})
            {
                $d->{files} += $_->{files};
                $d->{bytes} += $_->{bytes};
            }
        }
        return { dataset => $s };
    }
    else
    {
        $sth = undef;
        return $r;
    }
}


1;
