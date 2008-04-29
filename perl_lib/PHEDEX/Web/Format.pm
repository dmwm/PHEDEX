#!/usr/bin/env perl

package PHEDEX::Web::Format;

use warnings;
use strict;

use JSON::XS;     # for json format output
use Data::Dumper; # for perl format output
use HTML::Entities; # for encoding XML

our (%params);

%params = ( );

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = ref($proto) ? $class->SUPER::new(@_) : {};
    
    my %args = (@_);
    map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
    } keys %params; 

    bless $self, $class;
    return $self;
}

sub output
{
    my ($file, $format, $obj) = @_;
    die "object must be a hashref" unless ref($obj) eq 'HASH';
    $format ||= 'xml';

    my ($attr, $children) = gather($obj);
    die "root hash of _output can only have 1 child\n" if scalar @$children > 1;
    my $root = $children->[0];

    if ( $format eq 'xml' ) {
	my $version  = '1.0';
	my $encoding = 'ISO-8859-1';
	print $file "<?xml version='$version' encoding='$encoding'?>";
	xml_element($file, $root, $obj, 1);
    } elsif ( $format eq 'json' ) {
	# json_object($file, $root, $obj->{ $root });
	print encode_json($obj);
    } elsif ( $format eq 'perl' ) {
	print Dumper($obj);
    }
}

sub gather
{
    my ($hashref) = @_;
    return ([], [], '') unless ref $hashref eq 'HASH';

    my @attr;
    my @children;
    my $text = '';
    if (exists $hashref->{'$t'}) {
	$text = $hashref->{'$t'};
	delete $hashref->{'$t'};
    }
    foreach my $key (keys %$hashref) {
        if (!ref $hashref->{$key}) {
	    push @attr, $key;
        } else {
            push @children, $key;
        }
    }
    return \@attr, \@children, $text;
}

sub xml_element
{
    my ($file, $name, $obj, $is_root) = @_;
    my ($attr, $children, $text) = gather($obj);

    my $no_children;
    unless ($is_root) {
        $no_children = scalar @$children == 0 ? 1 : 0;
	# Avoiding HTML::Entities::encode_entities is about 30% more efficient for a large object.
	# But better safe than sorry.
        # print $file "<$name", join('', map { " $_='$obj->{$_}'" } @$attr);
        print $file "<$name", join('', map { (" $_='", 
					      (defined $obj->{$_} ? encode_entities($obj->{$_}) : ''),
					      "'") } @$attr);
        if ($no_children && !$text) {
            print $file "/>"; return;
        } else {
            print $file ">";
        }

	# Text data
	print $file encode_entities($text);
    }

    foreach my $child (@$children) {
        my $type = ref $obj->{$child};
        if ($type eq 'ARRAY') {
            foreach my $element (@{ $obj->{$child} }) {
                die "Array of '$child' elements contained a non-hash"
                    unless ref $element eq 'HASH';
		my $element_name = $child;
		if (defined $element->{element_name}) {
		    $element_name = $element->{element_name};
		    delete $element->{element_name};
		}
                xml_element($file, $element_name, $element);
            }
        } elsif ($type eq 'HASH') {
            xml_element($file, $child, $obj->{$child});
        }
    }

    print $file "</$name>" unless $is_root;
}

sub json_object
{
    my ($file, $name, $obj) = @_;
    $name = defined $name ? "\"$name\":" : '';
    my ($attr, $children) = gather($obj);

    if (ref $obj eq 'HASH') {
	print $file $name, "{";
	print $file join(',', map { "\"$_\"=\"$obj->{$_}\"" } @$attr);

	print $file ',' if  (@$attr && @$children);

	my $n = scalar @$children;
	my $i = 0;
	foreach my $child (@$children) {
	    json_object($file, $child, $obj->{$child});
	    print $file ',' unless ++$i == $n;
	}
	print $file "}";
    } elsif (ref $obj eq 'ARRAY') {
	my $n = scalar @{ $obj };
	my $i = 0;
	print $file $name, "[";
	foreach my $element (@{ $obj }) {
	    die "Array of '$name' elements contained a non-hash"
		unless ref $element eq 'HASH';
	    json_object($file, undef, $element);
	    print $file "," unless ++$i == $n;
	}
	print $file "]";
    }
}

1;
