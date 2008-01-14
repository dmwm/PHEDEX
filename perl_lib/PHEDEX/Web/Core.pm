#!/usr/bin/env perl

package PHEDEX::Web::Core;

use warnings;
use strict;

use base 'PHEDEX::Web::SQL';
use XML::XML2JSON;

our (%params);

%params = ( CONFIG => undef,
	    SECMOD => undef,
	    INSTANCE => undef
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

    $self->{DBCONFIG} = $self->{CONFIG}->{INSTANCES}->{$args{INSTANCE}}->{DBCONFIG};

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

sub call
{
    my ($self, $api, $format) = @_;
    no strict 'refs';
    if (!$api) {
	$self->error("No API call provided.  Check the URL");
	return;
    } elsif (!exists ${"PHEDEX::Web::Core::"}{$api}) {
	$self->error("API call '$api' is not defined.  Check the URL");
	return;
    } else {
	&connectToDatabase($self, 0);
	&{"PHEDEX::Web::Core::$api"}($self);
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
    my $self = shift;
    
    my $r = $self->getTransferStatus();

    my $converter = new XML::XML2JSON;
    print $converter->obj2json({ transferDetails => { status => $r } });

}

1;
