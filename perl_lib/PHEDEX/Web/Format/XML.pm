#!/usr/bin/env perl

package PHEDEX::Web::Format::XML;

use warnings;
use strict;
use Data::Dumper;

our (%params);

%params = ( );

sub new
{
    my $proto = shift;
    my $file = shift;
    if (! defined $file)
    {
        $file = *STDOUT;
    }
    my $class = ref($proto) || $proto;
    my $self  = ref($proto) ? $class->SUPER::new(@_) : {};
    $self->{FILE} = $file;
    my %args = (@_);
    map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
    } keys %params; 

    bless $self, $class;
    return $self;
}

# xml error
sub error
{
    my ($self, $message) = @_;
    $message ||= "no message";
    chomp $message;

    my $version = '1.0';
    my $encoding = 'ISO-8859-1';
    my $obj = { error => { '$t' => $message }};
    #print { $self->{FILE} } "<?xml version='$version' encoding='$encoding'?>";
    xml_element($self->{FILE}, 'error', $obj, 1);
};

# internal function
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

# header() -- output just the header
sub header
{
    my ($self, $obj) = @_;
    my $version  = '1.0';
    my $encoding = 'ISO-8859-1';
    print { $self->{FILE} } "<?xml version='$version' encoding='$encoding'?>";
    my ($attr, $children, $text) = gather($obj);
    my $name = $children->[0];
    ($attr, $children, $text) = gather($obj->{$name});
    print { $self->{FILE} } "<$name", join('',
            map { (" $_='", (defined $obj->{$name}->{$_}?encode_entities($obj->{$name}->{$_}) : ''),
            "'") } @$attr);
    print { $self->{FILE} } ">";
    if ($text)
    {
        print { $self->{FILE} } "<![CDATA[$text]]>";
    }
}

# footer() -- output just the footer
#
# in xml, it is (keys(%$obj))[0]
sub footer
{
    my ($self, $obj, $call_time) = @_;
    # no call_time for xml
    my $name = (keys(%$obj))[0];
    print { $self->{FILE} } "</$name>";
}

# separator between spooling -- nothing for xml
sub separator
{
    # do nothing for xml
    return 1;
}

sub output
{
    my ($self, $obj) = @_;

    xml_element($self->{FILE}, undef, $obj, 1);
}

# internal function
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
	if ($text) {
	    print $file "<![CDATA[$text]]>";
	}
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

sub try
{
	foreach (@_)
	{
		print Dumper($_);
	}
}
1;
