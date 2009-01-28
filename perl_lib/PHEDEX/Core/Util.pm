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
our @EXPORT_OK = qw( arrayref_expand str_hash );

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
    my $core = shift @_;
    my $str = shift @_;

    if ($str =~ m!(^\d*$)!)	# UNIX time
    {
        return $str =~ m!(^\d*$)!;
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

1;
