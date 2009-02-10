package PHEDEX::Namespace::tmdb::stat;
# Implements the 'stat' function for tmdb access
use strict;
use warnings;
use PHEDEX::BlockConsistency::SQL;

# @fields defines the actual set of attributes to be returned
our @fields = qw / size checksum_type checksum_size /;
sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;

  my $self = { };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  map { $self->{MAP}{$_}++ } @fields;
  return $self;
}

sub execute
{
  my ($self,$ns,$lfn) = @_;

  return 0 unless $lfn;
  my $r = { size => undef, checksum_type => undef, checksum_value => undef };
  my $tmp = PHEDEX::BlockConsistency::SQL::getTMDBFileStats($ns,$lfn);
  return $r unless $tmp;
# This code will break badly if getTMDBFileStats ever returns more than two values!
# For that matter, it would be much more efficient to use a bulk-query :-(
  $r->{size} = delete $tmp->{SIZE};
  my $checksum_type = (keys %{$tmp})[0];
  $r->{checksum_type} = $checksum_type;
  $r->{checksum_value} = $tmp->{$checksum_type};
  return $r;
}

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
