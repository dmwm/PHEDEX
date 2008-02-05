#!/usr/bin/env perl

package PHEDEX::Web::Core;

use warnings;
use strict;

use PHEDEX::Core::Timing;
use PHEDEX::Core::SQL;
use PHEDEX::Web::SQL;

use XML::XML2JSON;

our (%params);

%params = ( DBCONFIG => undef,
	    INSTANCE => undef,
	    REQUEST_URL => undef,
	    REQUEST_TIME => undef
	    );

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = ref($proto) ? $class->SUPER::new(@_) : {};
    
    my %args = (@_);
    map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
    } keys %params; 

    $self->{REQUEST_TIME} ||= &mytimeofday();

    bless $self, $class;

    return $self;
}

sub AUTOLOAD
{
    my $self = shift;
    my $attr = our $AUTOLOAD;
    $attr =~ s/.*:://;
    if ( exists($params{$attr}) )
    {
	$self->{$attr} = shift if @_;
	return $self->{$attr};
    }
    my $parent = "SUPER::" . $attr;
    $self->$parent(@_);
}

sub DESTROY
{
}

sub call
{
    my ($self, $call, %args) = @_;
    no strict 'refs';
    if (!$call) {
	$self->error("No API call provided.  Check the URL");
	return;
    } elsif (!exists ${"PHEDEX::Web::Core::"}{$call}) {
	$self->error("API call '$call' is not defined.  Check the URL");
	return;
    } else {
	&PHEDEX::Core::SQL::connectToDatabase($self, 0);
	$self->{DBH}->{FetchHashKeyName} = 'NAME_lc';
	my $t1 = &mytimeofday();
	my $obj = &{"PHEDEX::Web::Core::$call"}($self, %args);
	my $t2 = &mytimeofday();

	# wrap the object in a phedexData element
	$obj->{instance} = $self->{INSTANCE};
	$obj->{request_url} = $self->{REQUEST_URL};
	$obj->{request_call} = $call;
	$obj->{request_timestamp} = $self->{REQUEST_TIME};
	$obj->{request_date} = &formatTime($self->{REQUEST_TIME}, 'stamp');
	$obj->{call_time} = sprintf('%.5f', $t2 - $t1);
	$obj = { phedex => $obj };

	my $converter = new XML::XML2JSON(pretty => 0);
	if ($args{format} eq 'text/xml') {
	    print $converter->obj2xml($obj);
	} elsif ($args{format} eq 'text/javascript') {
	    print $converter->obj2json($obj);
	} else {
	    $self->error("return format requested is unknown or undefined");
	}
    }
}

sub error
{
    my $self = shift;
    my $msg = shift || "no message";
    print "<error>Error:  $msg</error>";
}

sub transferDetails
{
    my ($self, %h) = @_;
    
    my $r = &PHEDEX::Web::SQL::getTransferStatus($self, %h);
    return { transferDetails => { status => $r } };
}

sub blockReplicas
{
    my ($self, %h) = @_;
    my $r = &PHEDEX::Web::SQL::getBlockReplicas($self, %h);

    # Format into block->replica heirarchy
    my $blocks = {};
    foreach my $row (@$r) {
	my $id = $row->{block_id};
	
	# <block> element
	if (!exists $blocks->{ $id }) {
	    $blocks->{ $id } = { id => $id,
				 name => $row->{block_name},
				 files => $row->{block_files},
				 bytes => $row->{block_bytes},
				 is_open => $row->{is_open},
				 replica => []
				 };
	}
	
	# <replica> element
	push @{ $blocks->{ $id }->{replica} }, { id => $row->{node_id},
						 name => $row->{node_name},
						 storage_element => $row->{se_name},
						 files => $row->{replica_files},
						 bytes => $row->{replica_bytes},
						 time_create => $row->{replica_create},
						 time_update => $row->{replica_update},
						 complete => $row->{replica_complete}
					     };
    }

    return { block => [values %$blocks] };
}

sub nodes
{
    my ($self, %h) = @_;
    my $r = &PHEDEX::Web::SQL::getNodes($self, %h);
    return { node => $r };
}

1;
