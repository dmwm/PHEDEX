#!/usr/bin/env perl

package PHEDEX::Web::Format;

use warnings;
use strict;

use JSON::XS;     # for json format output
use Data::Dumper; # for perl format output

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
    die "root hash of output can only have 1 child\n" if scalar @$children > 1;
    my $root = $children->[0];

    if ( $format eq 'xml' ) {
	lc_keys($obj); # force keys to be lowercase
    	# special exception for the 'error' object
	# allow it to have a simple structure but be formatted as
	# <error>text</error>
	if (exists $obj->{error} && ! ref $obj->{error}) {
	    $obj = { error => { '$t' => $obj->{error} } }
	}
	my $version  = '1.0';
	my $encoding = 'ISO-8859-1';
	print { $file } "<?xml version='$version' encoding='$encoding'?>";
	xml_element($file, $root, $obj, 1);
    } elsif ( $format eq 'json' ) {
	lc_keys($obj); # force keys to be lowercase
	print { $file } encode_json($obj);
    } elsif ( $format eq 'perl' ) {
	# FIXME: this shouldn't be necessary.  Ensure all APIs return
	# uppercase key data structures by default then remove this
	# step
	uc_keys($obj); # force keys to be uppercase
	print { $file } Dumper($obj);
    }
}

sub error
{
    my ($file, $format, $message) = @_;
    $format ||= "xml";
    $message ||= "no message";
    chomp $message;
    
    &PHEDEX::Web::Format::output($file, $format, { error => $message });
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

    $name = lc $name;
    my $no_children;
    unless ($is_root) {
        $no_children = scalar @$children == 0 ? 1 : 0;
        print $file "<$name", join('', map { (" $_='", 
					      (defined $obj->{$_} ? encode_entities($obj->{$_}) : ''),
					      "'") } @$attr);
        if ($no_children && !$text) {
            print $file "/>"; return;
        } else {
            print $file ">";
        }

	# Text data
	print $file "<![CDATA[$text]]>";
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

# lowercase all hash keys
sub lc_keys
{
    my $o = shift;
    
    if (ref $o eq 'HASH') {
	foreach my $k (keys %$o) {
	    lc_keys($o->{$k}) if ref $o->{$k}; # recurce if ref
	    $o->{lc $k} = delete $o->{$k};
	}
    } elsif (ref $o eq 'ARRAY') {
	foreach my $e (@$o) { lc_keys($e); }   # recurse if array
    }
    return $o;
}

# uppercase all hash keys
# FIXME: same as above... how do I get a subref of a builtin and the
# function I'm in to reduce the duplicate?
sub uc_keys
{
    my $o = shift;
    
    if (ref $o eq 'HASH') {
	foreach my $k (keys %$o) {
	    uc_keys($o->{$k}) if ref $o->{$k}; # recurce if ref
	    $o->{uc $k} = delete $o->{$k};
	}
    } elsif (ref $o eq 'ARRAY') {
	foreach my $e (@$o) { uc_keys($e); }   # recurse if array
    }
    return $o;
}

# xml charcter encoding map
my %xml_char2entity = (
  '<' => '&lt;',
  '>' => '&gt;',
  '&' => '&amp;',
  "'" => '&apos;',
  '"' => '&quot;'
);

# compile a regexp
our $xml_char_regexp = join ('', keys %xml_char2entity);
$xml_char_regexp = qr/([$xml_char_regexp])/;

# encode xml characters
# special thanks to HTML::Entities in CPAN
sub encode_entities
{
    return undef unless defined $_[0];
    my $ref;
    if (defined wantarray) {
	my $x = $_[0];
	$ref = \$x;     # copy
    } else {
	$ref = \$_[0];  # modify in-place
    }
    $$ref =~ s/$xml_char_regexp/$xml_char2entity{$1}/ge;
    return $$ref;
}

1;
