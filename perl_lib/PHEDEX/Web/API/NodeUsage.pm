package PHEDEX::Web::API::NodeUsage;
use warnings;
use strict;
use PHEDEX::Web::SQL;

=pod

=head1 NAME

PHEDEX::Web::API::NodeUsage

=head1 DESCRIPTION

A summary of how space is used on a node.

=head2 Options

 node     PhEDex node names to filter on, can be multiple (*)

 (*) See the rules of multi-value filters in the Core module

=head2 Output

  <node/>
  ...

=head3 <node> attributes

 name                 PhEDEx node name
 cust_node_files      number of files in custodial storage
 cust_node_bytes      number of bytes in custodial storage
 cust_dest_files      number of files subscribed to custodial storage
 cust_dest_bytes      number of bytes subscribed to custodial storage
 noncust_node_files   number of files in non-custodial storage
 noncust_node_bytes   number of bytes in non-custodial storage
 noncust_dest_files   number of files subscribed to non-custodial storage
 noncust_dest_bytes   number of bytes subscribed to non-custodial storage
 src_node_files       number of files generated at this node but not subscribed
 src_node_bytes       number of bytes generated at this node but not subscribed
 nonsrc_node_files    number of files at the node but not subscribed or generated there
 nonsrc_node_bytes    number of bytes at the node but not subscribed or generated there

=cut

sub duration { return 5 * 60; }
sub invoke   { return nodeUsage(@_); }
sub nodeUsage
{
    my ($core, %h) = @_;

    # FIXME:  add node ID, se_name to output

    # $usage data structure:
    #   $usage->{$node}->{$category} = { data }
    my $usage = &PHEDEX::Web::SQL::getNodeUsage($core, %h);
    my $result = [];
    foreach my $node (keys %$usage) {
	my $row = { NAME => $node };
	# subscribed data: custodial categories
	foreach my $c (qw(CUST NONCUST)) {
	    foreach my $a (qw(NODE_FILES NODE_BYTES DEST_FILES DEST_BYTES)) {
		$row->{ $c.'_'.$a } = $usage->{$node}->{ 'SUBS_'. $c }->{$a}  || 0;		
	    }
	}
	# non-subscribed data: source categories
	foreach my $s (qw(SRC NONSRC)) {
	    foreach my $a (qw(NODE_FILES NODE_BYTES)) {
		$row->{ $s.'_'.$a } = $usage->{$node}->{ 'NONSUBS_'.$s }->{$a} || 0;		
	    }
	}
	push @$result, $row;
    }
    return { node => $result };
}

1;
