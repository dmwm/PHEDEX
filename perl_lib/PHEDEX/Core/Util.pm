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
our @EXPORT_OK = qw( arrayref_expand str_hash str2time deep_copy );

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

# str2time -- convert string to timestamp
# possible input values:
#    UNIX time
#    YYYY-MM-DD[_hh:mm:ss]
#    now
#    last_hour
#    last_12hours
#    last_day
#    last_7days
#    last_30days
#    last_180days
sub str2time
{
    my $str = shift @_;

    if ($str =~ m!(^\d*$)!)	# UNIX time
    {
        return $str;
    }
    elsif ($str eq "now")
    {
        return time();
    }
    elsif ($str eq "last_hour")
    {
        return time() - 3600;
    }
    elsif ($str eq "last_12hours")
    {
        return time() - 43200;
    }
    elsif ($str eq "last_day")
    {
        return time() - 86400;
    }
    elsif ($str eq "last_7days")
    {
        return time() - 604800;
    }
    elsif ($str eq "last_30days")
    {
        return time() - 2592000;
    }
    elsif ($str eq "last_180days")
    {
        return time() - 15552000;
    }

    # YYYY-MM-DD[_hh:mm:ss]
    my @t = $str =~ m!(\d{4})-(\d{2})-(\d{2})([\s_](\d{2}):(\d{2}):(\d{2}))?!;
    if (not $t[3]) # no time information, assume 00:00:00
    {
        $t[4] = 0;
        $t[5] = 0;
        $t[6] = 0;
    }
    return POSIX::mktime($t[6], $t[5], $t[4], $t[2], $t[1]-1, $t[0]-1900);
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
    
    if (defined $local_remote) {
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
          KEY ::= identifier
        VALUE ::= string | number | MAP

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
#           KEY ::= identifier
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
        # if there is an element witht the key
        my $key = $input->{$map->{_KEY}};

        if (exists $output->{$key})
        {
            foreach $k (keys %{$map})
            {
                if (ref($map->{$k}) eq "HASH")
                {
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
                $h->{$k}->{$k1} = hash2list($v->{$k1});
            }
        }
        push @r, $h->{$k};
    }
    return \@r;
}

# flat2tree -- turn list of flat hashes into list of structured list of hashes
sub flat2tree
{
    my ($map, $input) = @_;
    my $out = {};
    foreach(@$input)
    {
        build_hash($map, $_, $out);
    }
    return hash2list($out);
}

1;
