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
	$priority = $priority + $local_remote;
    }
    
    return $priority;
}

1;
