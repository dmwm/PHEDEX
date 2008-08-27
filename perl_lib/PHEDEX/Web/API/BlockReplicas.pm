package PHEDEX::Web::API::BlockReplicas;
use warnings;
use strict;
use PHEDEX::Web::Util;

=pod

=head1 NAME

PHEDEX::Web::API::BlockReplicas - list block replicas in PhEDEx

=head1 SYNOPSIS

=head2 blockReplicas

Return block replicas with the following structure:

  <block>
     <replica/>
     <replica/>
      ...
  </block>
   ...

where <block> represents a block of files and <replica> represents a
copy of that block at some node.  An empty response means that no
block replicas exist for the given options.

=head3 options

 block          block name, can be multiple (*)
 node           node name, can be multiple (*)
 se             storage element name, can be multiple (*)
 update_since  unix timestamp, only return replicas updated since this
                time
 create_since   unix timestamp, only return replicas created since this
                time
 complete       y or n, whether or not to require complete or incomplete
                blocks. Default is to return either

 (*) See the rules of multi-value filters in the Core module

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

=cut

sub duration { return 5 * 60; }
sub invoke { return blockReplicas(@_); }
sub blockReplicas
{
    my ($self,$core,%h) = @_;

    foreach ( qw / BLOCK NODE SE CREATE_SINCE UPDATE_SINCE COMPLETE / )
    {
      $h{lc $_} = delete $h{$_} if $h{$_};
    }
    my $r = PHEDEX::Web::SQL::getBlockReplicas($core, %h);

    # Format into block->replica heirarchy
    my $blocks = {};
    foreach my $row (@$r) {
	my $id = $row->{block_id};
	
	# <block> element
	if (!exists $blocks->{ $id }) {
	    $blocks->{ $id } = { id => $id,
				 name => $row->{BLOCK_NAME},
				 files => $row->{BLOCK_FILES},
				 bytes => $row->{BLOCK_BYTES},
				 is_open => $row->{IS_OPEN},
				 replica => []
				 };
	}
	
	# <replica> element
	push @{ $blocks->{ $id }->{replica} }, { node_id => $row->{NODE_ID},
						 node => $row->{NODE_NAME},
						 se => $row->{SE_NAME},
						 files => $row->{REPLICA_FILES},
						 bytes => $row->{REPLICA_BYTES},
						 time_create => $row->{REPLICA_CREATE},
						 time_update => $row->{REPLICA_UPDATE},
						 complete => $row->{REPLICA_COMPLETE}
					     };
    }

    return { block => [values %$blocks] };
}

1;
