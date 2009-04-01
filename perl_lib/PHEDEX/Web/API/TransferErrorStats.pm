package PHEDEX::Web::API::TransferErrorStats;
#use warning;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferErrorStats - return transfer error stats

=head2 transfererrorstats

Return transfer error information in the following format

  <link from= from_id= from_se= to= to_id= to_se= >
    <block name= id= num_errors= >
      <file name= id= bytes= checksum= num_errors= />
    </block>
  </link>

=head3 options

 required inputs: none
 optional inputs: (as filters) from, to, block, lfn

  from             name of the source node, could be multiple
  to               name of the destination node, could be multiple
  block            block name
  lfn              logical file name

=head3 output

  <link from= from_id= from_se= to= to_id= to_se= >
    <block name= id= num_errors= >
      <file name= id= bytes= checksum= num_errors= />
    </block>
  </link>

=head3 <link> elements:

  from             name of the source node
  from_id          id of the source node
  to               name of the destination node
  to_id            id of the destination node
  from_se          se of the source node
  to_se            se of the destination node

=head3 <block> elements:

  name             block name
  id               block id
  num_errors       number of errors

=head3 <file> elements:

  name             file name
  id               file id
  bytes            file length
  checksum         checksum
  num_errors       number of errors

=cut


use PHEDEX::Web::SQL;

sub duration { return 60 * 60; }
sub invoke { return transfererrorstats(@_); }

sub transfererrorstats
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / from to block lfn / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    my $r = PHEDEX::Web::SQL::getTransferErrorStats($core, %h);
    return { link => $r };
}

1;
