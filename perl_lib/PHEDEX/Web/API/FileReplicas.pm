package PHEDEX::Web::API::FileReplicas;
use warnings;
use strict;
use PHEDEX::Web::Util;
use PHEDEX::Web::SQL;

=pod

=head1 NAME

PHEDEX::Web::API::FileReplicas - return file-replicas known to PhEDEx

=head2 fileReplicas

Return file replicas with the following structure:

  <block>
     <file>
       <replica/>
       <replica/>
       ...
     </file>
     ...
  </block>
   ...

where <block> represents a block of files, <file> represents a file
and <replica> represents a copy of that file at some node.  <block>
and <file> will always be present if any file replicas match the given
options.  <file> elements with no <replica> children represent files
which are part of the block, but no file replicas match
the given options.  An empty response means no file replicas matched
the given options.

=head3 options

 block          block name, with '*' wildcards, can be multiple (*).  required.
 node           node name, can be multiple (*)
 se             storage element name, can be multiple (*)
 update_since  unix timestamp, only return replicas updated since this
                time
 create_since   unix timestamp, only return replicas created since this
                time
 complete       y or n. if y, return only file replicas from complete block
                replicas.  if n only return file replicas from incomplete block
                replicas.  default is to return either.
 dist_complete  y or n.  if y, return only file replicas from blocks
                where all file replicas are available at some node. if
                n, return only file replicas from blocks which have
                file replicas not available at any node.  default is
                to return either.

 (*) See the rules of multi-value filters in the Core module

=head3 <block> attributes

 name     block name
 id       PhEDEx block id
 files    files in block
 bytes    bytes in block
 is_open  y or n, if block is open

=head3 <file> attributes

 name         logical file name
 id           PhEDEx file id
 bytes        bytes in the file
 checksum     checksum of the file
 origin_node  node name of the place of origin for this file
 time_create  time that this file was born in PhEDEx

=head3 <replica> attributes

 node         PhEDEx node name
 node_id      PhEDEx node id
 se           storage element name
 time_create  unix timestamp

=cut

sub duration{ return 5 * 60; }
sub invoke { return fileReplicas(@_); }
sub fileReplicas
{
    my ($core,%h) = @_;

    &checkRequired(\%h, 'block');

    my $r = PHEDEX::Web::SQL::getFileReplicas($core, %h);

    my $blocks = {};
    my $files = {};
    my $replicas = {};
    foreach my $row (@$r) {
	my $block_id = $row->{BLOCK_ID};
	my $node_id = $row->{NODE_ID};
	my $file_id = $row->{FILE_ID};

	# <block> element
	if (!exists $blocks->{ $block_id }) {
	    $blocks->{ $block_id } = { id => $block_id,
				       name => $row->{BLOCK_NAME},
				       files => $row->{BLOCK_FILES},
				       bytes => $row->{BLOCK_BYTES},
				       is_open => $row->{IS_OPEN},
				       file => []
				   };
	}

	# <file> element
	if (!exists $files->{ $file_id }) {
	    $files->{ $file_id } = { id => $row->{FILE_ID},
				     name => $row->{LOGICAL_NAME},
				     bytes => $row->{FILESIZE},
				     checksum => $row->{CHECKSUM},
				     time_create => $row->{TIME_CREATE},
				     origin_node => $row->{ORIGIN_NODE},
				     replica => []
				 };
	    push @{ $blocks->{ $block_id }->{file} }, $files->{ $file_id };
	}
	
	# <replica> element
	next unless defined $row->{NODE_ID};
	push @{ $files->{ $file_id }->{replica} }, { node_id => $row->{NODE_ID},
						     node => $row->{NODE_NAME},
						     se => $row->{SE_NAME},
						     time_create => $row->{REPLICA_CREATE}
						 };
    }
    
    return { block => [values %$blocks] };
}

1;
