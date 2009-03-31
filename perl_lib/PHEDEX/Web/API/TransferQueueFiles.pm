package PHEDEX::Web::API::TransferQueueFiles;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::TransferQueueFiles - show files in the transfer queue

=head3 options

 required inputs:   none
 optional inputs:   from, to, priority

 from               name of the from (source) node, could be multiple
 to                 name of the to (destination) node, could be multiple

=head3 output:

  <link>
     <transfer_queue>
       <block>
          <file/>
          ...
       </block>
       ...
     </transfer_queue>
     ...
  </link>
  ...

=head3 <link> elements:

 from               name of the from (source) node
 to                 name of the to (destination) node
 from_id            id of the from node
 to_id              id of the to node

=head3 <transfer_queue> elements:

 priority           transfer priority
 files              number of files in transfer
 bytes              number of bytes in transfer
 time_update        time when it was updated
 state              "assigned", "exported", "transferring", or "transferred"

=cut

use PHEDEX::Web::SQL;
use Data::Dumper;

sub duration { return 60 * 60; }
sub invoke { 
    my ($core, %h) = @_;

    # convert parameter key to upper case
    foreach ( qw / from to priority / )
    {
	$h{uc $_} = delete $h{$_} if $h{$_};
    }
    
    my $r = PHEDEX::Web::SQL::getTransferQueueFiles($core, %h);

    # Transform the flat representation into a heirarchy
    my $links = {};
    foreach my $row ( @$r ) {
	# link
	my $link_key = $row->{FROM_ID}.':'.$row->{TO_ID};
	$links->{$link_key} = 
         { FROM => $row->{FROM_NODE},
	   FROM_ID => $row->{FROM_ID},
	   FROM_SE => $row->{FROM_SE},
	   TO => $row->{TO_NODE},
	   TO_ID => $row->{TO_ID},
	   TO_SE => $row->{TO_SE},
	   Q_HASH => {}
          } unless $links->{$link_key};

	# queue
	my $queue_key = $row->{STATE}.':'.$row->{PRIORITY};
	my $queue = $links->{$link_key}->{Q_HASH}->{$queue_key} || {};
	$queue = 
	{ STATE => $row->{STATE}, 
	  PRIORITY => $row->{PRIORITY},
	  B_HASH => {} } unless %$queue;

	# block
	my $block_key = $row->{BLOCK_ID};
	my $block = $queue->{B_HASH}->{$block_key} || {};
	$block =
	{ NAME => $row->{BLOCK_NAME},
	  ID => $row->{BLOCK_ID},
	  FILE => [] } unless %$block;
	
	# file
	push @{$block->{FILE}}, { NAME => $row->{LOGICAL_NAME},
				  ID => $row->{FILE_ID},
				  BYTES => $row->{FILESIZE},
				  CHECKSUM => $row->{CHECKSUM} };
    }
    
    # Transform hashes into arrays for auto-formatting
    foreach my $link (values %$links) {
	foreach my $queue (values %{$link->{Q_HASH}}) {
	    foreach my $block (values %{$queue->{B_HASH}}) {
		$queue->{BLOCK} ||= [];
		push @{$queue->{BLOCK}}, $block;
	    }
	    delete $queue->{B_HASH};
	    $r->{TRANSFER_QUEUE} ||= [];
	    push @{$r->{TRANSFER_QUEUE}}, $queue;
	}
	delete $link->{Q_HASH};
    }
    
    return { LINK => [ values %$links ] };
}

1;
