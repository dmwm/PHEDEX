package PHEDEX::Core::Util;

=pod

=head1 NAME

PHEDEX::Core::Util - basic utility functions that may be useful in any module

=cut

use warnings;
use strict;
use Data::Dumper;
use List::Util qw(max min sum);

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

PHEDEX::Core::Util::flat2tree -- turn a list of flat hashes into a list of hierarchical ones

=head1 DESCRIPTION

Turn SQL result in a flat hash into hierarchical structure defined by the mapping

=head2 Syntax

=head3 input: a flat hash

        INPUT ::= { ELEMENT_LIST }
 ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT
      ELEMENT ::= KEY => VALUE
          KEY ::= identifier
        VALUE ::= string | number

=head3 mapping:

          MAP ::= { _KEY => KEY1, ELEMENT_LIST }
         KEY1 ::= identifier | identifier+KEY1
 ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT
      ELEMENT ::= KEY => VALUE
          KEY ::= string
        VALUE ::= identifier | number | MAP | [ TYPE_FUNC, PARAMS ]
    TYPE_FUNC ::= KNOWN_TYPE | code_reference
   KNOWN_TYPE ::= string
       PARAMS ::= PARAM | PARAMS , PARAM
        PARAM ::= identifier

 * KEY1 could be a compound key made from multiple elements in above input
 * identifier is a string of an element key in the input

=head3 output:

            OUTPUT ::= [ ELEMENT_LIST ]
      ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT 
           ELEMENT ::= HASH
              HASH ::= { HASH_ELEMENT_LIST }
 HASH_ELEMENT_LIST ::= HASH_ELEMENT | HASH_ELEMENT_LIST , HASH_ELEMENT
      HASH_ELEMENT ::= KEY => VALUE
               KEY ::= string
             VALUE ::= string | number | OUTPUT

=head3 aggregation functions:

     sum()
     count()
     max()
     min()

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
#          KEY1 ::= identifier | identifier+KEY1
#  ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT
#       ELEMENT ::= KEY => VALUE
#           KEY ::= string
#         VALUE ::= identifier | number | MAP | [ TYPE_FUNC, PARAMS ]
#     TYPE_FUNC ::= KNOWN_TYPE | code_reference
#    KNOWN_TYPE ::= string
#        PARAMS ::= PARAM | PARAMS , PARAM
#         PARAM ::= identifier
# 
#  output:
# 
#             OUTPUT ::= [ ELEMENT_LIST ]
#       ELEMENT_LIST ::= ELEMENT | ELEMENT_LIST , ELEMENT 
#            ELEMENT ::= HASH
#               HASH ::= { HASH_ELEMENT_LIST }
#  HASH_ELEMENT_LIST ::= HASH_ELEMENT | HASH_ELEMENT_LIST , HASH_ELEMENT
#       HASH_ELEMENT ::= KEY => VALUE
#                KEY ::= string
#              VALUE ::= string | number | OUTPUT
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

        if (! exists $output->{$key})
        {
            $output->{$key} = {};
        }

        foreach $k (keys %{$map})
        {
            if ($k ne "_KEY")
            {
                if (ref($map->{$k}) eq "HASH")
                {
                    if (not exists $output->{$key}->{$k})
                    {
                        $output->{$key}->{$k} = {};
                    }
                    build_hash($map->{$k}, $input, $output->{$key}->{$k});
                }
                else
                {
                    # supply $output->{$key}->{$k} for aggregation function
                    $output->{$key}->{$k} = _get_value($input, $map->{$k}, $output->{$key}->{$k});
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

# _get_value -- get value from $input->{$field} according to $field definition
# allow map definition to include type conversion information
# type function is able to take more than one parameters
# $acc_val is carried for aggregation functions but it could be anything
sub _get_value
{
    my ($input, $field, $acc_val) = @_;

    if (ref($field) eq 'ARRAY')
    {
        my @param = @{$field};
        my $type = shift @param;
        if (ref($type) eq 'CODE')
        {
            return &{$type}(map {$input->{$_}} @param);
        }

        # predefined functions
        if ($type eq 'int')
        {
            return int(shift @param);
        }
        elsif ($type eq 'sum')
        {
            if (defined $acc_val)
            {
                return ($input->{shift @param}) + $acc_val;
            }
            else
            {
                return ($input->{shift @param});
            }
        }
        elsif ($type eq 'count')
        {
            if (defined $acc_val)
            {
                return $acc_val + 1;
            }
            else
            {
                return 1;
            }
        }
        elsif ($type eq 'max')
        {
            my @param2 = map {$input->{$_}} @param;
            if (defined $acc_val)
            {
                push @param2, $acc_val;
            }
            return max(@param2);
        }
        elsif ($type eq 'min')
        {
            my @param2 = map {$input->{$_}} @param;
            if (defined $acc_val)
            {
                push @param2, $acc_val;
            }
            return min(@param2);
        }
    }
    else
    {
        return $input->{$field};
    }
}

1;
