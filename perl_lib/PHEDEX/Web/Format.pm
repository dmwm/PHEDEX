#!/usr/bin/env perl

package PHEDEX::Web::Format;

use warnings;
use strict;

use JSON::XS;     # for json format output
use Data::Dumper; # for perl format output
use PHEDEX::Web::Util;
use PHEDEX::Core::Loader;

our (%params);

%params = ( );

sub new
{
    my $proto = shift;
    my $format = shift;
    my $file = shift;

    my $loader = PHEDEX::Core::Loader->new( NAMESPACE => 'PHEDEX::Web::Format');
    my $module = $loader->Load($format);
    die "no formatter module for $format" if ! $module;
    return $module->new($file);
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
	PHEDEX::Web::Util::lc_keys($obj); # force keys to be lowercase
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
	PHEDEX::Web::Util::lc_keys($obj); # force keys to be lowercase
	print { $file } encode_json($obj);
    } elsif ( $format eq 'cjson' ) {
        PHEDEX::Web::Util::lc_keys($obj); # force keys to be lowercase
        #print { $file } Dumper($obj->{'phedex'});
        my ($cobj,$k, $v, $temp);
        $temp = compress($file, $obj->{'phedex'});
        while (($k, $v) = each (%{$obj->{'phedex'}}))
        {
            $cobj->{'phedex'}->{$k} = $v;
            if (ref($v) eq "ARRAY") {
                $cobj->{'phedex'}->{$k} = $temp;
            }
        }
        print { $file } encode_json($cobj);
    } elsif ( $format eq 'perl' ) {
	# FIXME: this shouldn't be necessary.  Ensure all APIs return
	# uppercase key data structures by default then remove this
	# step
	PHEDEX::Web::Util::uc_keys($obj); # force keys to be uppercase
	print { $file } Dumper($obj);
    }
}

sub error
{
    my ($file, $format, $message) = @_;
    $format ||= "xml";
    $message ||= "no message";
    chomp $message;
    
    $message =~ s% at /\S+/perl_lib/PHEDEX/\S+pm line \d+%%;
    &PHEDEX::Web::Format::output($file, $format, { error => $message });
}

sub compress
{
    my ($file, $h) = @_;
    my ($k, $v, $sub, $k2, $a);
    my %ch;

    #print { $file } Dumper($h);
    while (($k, $v) = each (%$h))
    {
       if (ref($v) eq "ARRAY") {
          #print { $file } Dumper($v->[0]);
          foreach $k2 (keys %{$v->[0]}) {
            push @{$ch{'column'}}, $k2;
          }
          foreach $a (@$v) {
            $sub = [];
            foreach $k2 (keys %$a)
            {
              if (ref($a->{$k2}) eq "ARRAY")
              {
                #print { $file } Dumper($a->{$k2});
                $a->{$k2} = compress($file, $a);
              }
              push @$sub, $a->{$k2};
            }
            #print { $file } Dumper($sub);
            push @{$ch{'values'}}, $sub; 
         }
       }
    }
    return \%ch;
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
