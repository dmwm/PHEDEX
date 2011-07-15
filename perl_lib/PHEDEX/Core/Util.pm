package PHEDEX::Core::Util;

=pod

=head1 NAME

PHEDEX::Core::Util - basic utility functions that may be useful in any module

=cut

use warnings;
use strict;
use Data::Dumper;

our @ISA = qw(Exporter);
our @EXPORT = qw (); # export nothing by default
our @EXPORT_OK = qw( arrayref_expand str_hash deep_copy );

#-------------------------------------------------------------------------------
# Takes an array and expands all arrayrefs in the array
sub arrayref_expand
{
    my @out;
    foreach (@_) {
	if    (!ref $_)           { push @out, $_; }
	elsif (ref $_ eq 'ARRAY') { push @out, @$_; } 
	else { next; }
    }
    return @out;
}

sub str_hash
{
# returns an inline data-dumper dump of its arguments
  $Data::Dumper::Terse=1;
  $Data::Dumper::Indent=0;
  my $a = Data::Dumper->Dump([\@_]);
  $a =~ s%\n%%g;
  $a =~ s%\s\s+% %g;
  return $a;
}

sub deep_copy {
# As the name implies, make a deep-copy of the input and return the result
  my $this = shift;
  if (not ref $this) {
    $this;
  } elsif (ref $this eq "ARRAY") {
    [map deep_copy($_), @$this];
  } elsif (ref $this eq "HASH") {
    +{map { $_ => deep_copy($this->{$_}) } keys %$this};
  } else { die "what type is $_?" }
}

# name of the priority
my %priority_names = (
    0 => 'high',
    1 => 'normal',
    2 => 'low' );

# when $local_remote is false, $priority is interepreted as-is
#
# when $local_remote is true, the even numbers are for local and
# the odd numbers are for remote; the priority is "decoded" as follows
#
# $priority = ($priority - ($priority % 2))/2;
# 
sub priority
{
    my ($priority, $local_remote) = @_;

    if ($local_remote)
    {
        $priority = ($priority - ($priority % 2))/2;
    }

    return $priority_names{$priority};
}

sub priority_num
{
    my ($priority_name, $local_remote) = @_;
    my %priority_nums = reverse %priority_names;
    my $priority = $priority_nums{lc $priority_name};
    
    if ($local_remote) {
	$priority = $priority*2 + $local_remote;
    }
    
    return $priority;
}

=pod

=head1 NAME

PHEDEX::Core::Util::flat2tree -- turn a list of flat hashes into a list of hierachical ones

=head1 DESCRIPTION

Turn SQL result in a flat hash into hierachical structure defined by
the mapping

=head2 Syntax

=head3 input: a flat hash

        INPUT ::= { ELEMENT_LIST }
 ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT
      ELEMENT ::= KEY => VALUE
          KEY ::= identifier
        VALUE ::= string | number

=head3 mapping:

          MAP ::= { _KEY => KEY, ELEMENT_LIST }
 ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT
      ELEMENT ::= KEY => VALUE
          KEY ::= identifier | identifier+KEY
        VALUE ::= string | number | MAP

 * KEY could be a compound key made from multiple elements in above input

=head3 output:

 OUTPUT ::= [ ELEMENT_LIST ]
 ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT 
 ELEMENT ::= HASH
 HASH ::= { HASH_ELEMENT_LIST }
 HASH_ELEMENT_LIST ::= HASH_ELEMENT | HASH_ELEMENT_LIST , HASH_ELEMENT
 HASH_ELEMENT ::= KEY => VALUE
 KEY ::= identifier
 VALUE ::= string | number | OUTPUT

=cut

# build_hash -- according to the map, build a structure out of input
# 
#  input: a flat hash
# 
#         INPUT ::= { ELEMENT_LIST }
#  ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT
#       ELEMENT ::= KEY => VALUE
#           KEY ::= identifier
#         VALUE ::= string | number
# 
#  mapping:
# 
#           MAP ::= { _KEY => KEY, ELEMENT_LIST }
#  ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT
#       ELEMENT ::= KEY => VALUE
#           KEY ::= identifier | identifier+KEY
#         VALUE ::= string | number | MAP
# 
#  output:
# 
#  OUTPUT ::= [ ELEMENT_LIST ]
#  ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT 
#  ELEMENT ::= HASH
#  HASH ::= { HASH_ELEMENT_LIST }
#  HASH_ELEMENT_LIST ::= HASH_ELEMENT | HASH_ELEMENT_LIST , HASH_ELEMENT
#  HASH_ELEMENT ::= KEY => VALUE
#  KEY ::= identifier
#  VALUE ::= string | number | OUTPUT
# 
sub build_hash
{
    my ($map, $input, $output) = @_;
    my $k;

    # the $map must be a hash reference
    if (ref($map) eq "HASH")
    {
        # if there is an element with the key
        my $key = join ('+', (map {$input->{$_}||''} split('\+', $map->{_KEY})));

        # skip generating output if there is no key value
        if ($key eq '')
        {
            return;
        }

        if (exists $output->{$key})
        {
            foreach $k (keys %{$map})
            {
                if (ref($map->{$k}) eq "HASH")
                {
                    # take care of non-existing $output->{$key}->{$k}
                    $output->{$key}->{$k} = {} if (! exists $output->{$key}->{$k});
                    build_hash($map->{$k}, $input, $output->{$key}->{$k});
                }
            }
        }
        else
        {
            $output->{$key} = {};
            foreach $k (keys %{$map})
            {
                if ($k ne "_KEY")
                {
                    if (ref($map->{$k}) eq "HASH")
                    {
                        $output->{$key}->{$k} = {};
                        build_hash($map->{$k}, $input, $output->{$key}->{$k});
                    }
                    else
                    {
                        $output->{$key}->{$k} = $input->{$map->{$k}};
                    }
                }
            }

        }
    }
    else
    {
        # this is an error
        die "error parsing structure definition";
    }
}

# hash2list -- recurrsively turn hash into a list of its values
sub hash2list
{
    my $h = shift;
    my ($k, $v, $k1);
    my @r;

    while (($k, $v) = each (%$h))
    {
        foreach $k1 (keys %$v)
        {
            if (ref($v->{$k1}) eq "HASH")
            {
                # ignore {'$T' => text }
                my @k2 = keys %{$v->{$k1}};
                if (!((@k2 == 1) && (($k2[0] eq '$T') || ($k2[0] eq '$t'))))
                {
                    $h->{$k}->{$k1} = hash2list($v->{$k1});
                }
            }
        }
        push @r, $h->{$k};
    }
    return \@r;
}

# flat2tree -- turn list of flat hashes into list of structured list of hashes
sub flat2tree
{
    my ($map, $input, $out) = @_;
    if (not defined $out)
    {
        $out = {};
    }

    foreach(@$input)
    {
        build_hash($map, $_, $out);
    }
    return hash2list($out);
}

1;
