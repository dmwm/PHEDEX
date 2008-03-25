#!/usr/bin/env perl

package PHEDEX::Web::Core;

use warnings;
use strict;

use PHEDEX::Core::Timing;
use PHEDEX::Core::SQL;
use PHEDEX::Web::SQL;
use PHEDEX::Web::Format;

# If you're thinking of these, I've already tried them and decided against.
#use Cache::FileCache;
#use Cache::MemoryCache;
#use XML::XML2JSON;
#use XML::Writer;

our (%params);

%params = ( DBCONFIG => undef,
	    INSTANCE => undef,
	    REQUEST_URL => undef,
	    REQUEST_TIME => undef,
	    DEBUG => 0
	    );

# A map of API calls to data sources
our $call_data = {
    linkTasks       => [ qw( linkTasks ) ],
    blockReplicas   => [ qw( blockReplicas ) ],
    nodes           => [ qw( nodes ) ],
    catalogue       => [ qw( catalog ) ]
};

# Data source parameters
our $data_sources = {
    linkTasks       => { DATASOURCE => \&PHEDEX::Web::SQL::getLinkTasks,
			 DURATION => 10*60 },
    blockReplicas   => { DATASOURCE => \&PHEDEX::Web::SQL::getBlockReplicas,
			 DURATION => 5*60 },
    nodes           => { DATASOURCE => \&PHEDEX::Web::SQL::getNodes,
			 DURATION => 60*60 },
    catalog         => { DATASOURCE => \&PHEDEX::Web::SQL::getCatalog,
			 DURATION => 15*60 }
};

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

    # Set up database connection
    my $t1 = &mytimeofday();
    &PHEDEX::Core::SQL::connectToDatabase($self, 0);
    my $t2 = &mytimeofday();
    warn "db connection time ", sprintf('%.6f s', $t2-$t1), "\n" if $self->{DEBUG};

    $self->{DBH}->{FetchHashKeyName} = 'NAME_lc';

#    $self->{CACHE} = new Cache::FileCache({cache_root => '/tmp/phedex-cache'});
#    $self->{CACHE} = new Cache::MemoryCache;
    
    bless $self, $class;

    # on initialization fill the caches
#    foreach my $call (grep $cacheable{$_} > 0, keys %cacheable) {
#	$self->refreshCache($call);
#    }

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
	my $t1 = &mytimeofday();
	my $obj;
	eval {
	    $obj = &{"PHEDEX::Web::Core::$call"}($self, %args, nocache=>1);
	};
	if ($@) {
	    $self->error("Error when making call '$call':  $@");
	    return;
	}
	my $t2 = &mytimeofday();
	warn "api call '$call' complete in ", sprintf('%.6f s', $t2-$t1), "\n" if $self->{DEBUG};

	# wrap the object in a phedexData element
	$obj->{instance} = $self->{INSTANCE};
	$obj->{request_url} = $self->{REQUEST_URL};
	$obj->{request_call} = $call;
	$obj->{request_timestamp} = $self->{REQUEST_TIME};
	$obj->{request_date} = &formatTime($self->{REQUEST_TIME}, 'stamp');
	$obj->{call_time} = sprintf('%.5f', $t2 - $t1);
	$obj = { phedex => $obj };

	$t1 = &mytimeofday();
	if (grep $_ eq $args{format}, qw( xml json perl )) {
	    &PHEDEX::Web::Format::output(*STDOUT, $args{format}, $obj);
	} else {
	    $self->error("return format requested is unknown or undefined");
	}
	$t2 = &mytimeofday();
	warn "api call '$call' delivered in ", sprintf('%.6f s', $t2-$t1), "\n" if $self->{DEBUG};
    }
}

sub error
{
    my $self = shift;
    my $msg = shift || "no message";
    chomp $msg;
    print "<error>\n", encode_entities($msg),"\n</error>";
}


# API Calls 

sub linkTasks
{
    my ($self, %h) = @_;
    
    my $r = $self->getData('linkTasks', %h);
    return { linkTasks => { status => $r } };
}

sub blockReplicas
{
    my ($self, %h) = @_;

    my $r = $self->getData('blockReplicas', %h);

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
    my $r = $self->getData('nodes', %h);
    return { node => $r };
}

sub catalogue
{
    my ($self, %h) = @_;
    my $r = $self->getData('catalogue', %h);
    return { catalog => $r };
}

# Cache controls

sub refreshCache
{
    my ($self, $call) = @_;
    
    foreach my $name (@{ $call_data->{$call} }) {
	my $datasource = $data_sources->{$name}->{DATASOURCE};
	my $duration   = $data_sources->{$name}->{DURATION};
	my $data = &{$datasource}($self);
	$self->{CACHE}->set( $name, $data, $duration.' s' );
    }
}

sub getData
{
    my ($self, $name, %h) = @_;

    my $datasource = $data_sources->{$name}->{DATASOURCE};
    my $duration   = $data_sources->{$name}->{DURATION};

    my $t1 = &mytimeofday();

    my $from_cache;
    my $data;
    $data = $self->{CACHE}->get( $name ) unless $h{nocache};
    if (!defined $data) {
	$data = &{$datasource}($self, %h);
	$self->{CACHE}->set( $name, $data, $duration.' s') unless $h{nocache};
	$from_cache = 0;
    } else {
	$from_cache = 1;
    }

    my $t2 = &mytimeofday();

    warn "got '$name' from ",
    ($from_cache ? 'cache' : 'DB'),
    " in ", sprintf('%.6f s', $t2-$t1), "\n" if $self->{DEBUG};

    return wantarray ? ($data, $from_cache) : $data;
}


# Returns the cache duration for a API call.  If there are multiple
# data sources in an API call then the one with the lowest duration is
# returned
sub getCacheDuration
{
    my ($self, $call) = @_;
    my $min;
    foreach my $name (@{ $call_data->{$call} }) {
	my $duration   = $data_sources->{$name}->{DURATION};
	$min ||= $duration;
	$min = $duration if $duration < $min;
    }
    return $min;
}


1;
