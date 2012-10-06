package PHEDEX::Namespace::dcache::checksum;
# Implements the 'checksum' function for dcache access
use strict;
use warnings;
use PHEDEX::Core::Catalogue;

# @fields defines the actual set of attributes to be returned
our @fields = qw / checksum_type checksum_value /; 

sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
# This shows the use of an external command to stat the file. It would be
# possible to do this with Perl inbuilt 'stat' function, of course, but this
# is just an example.
  my $self = {
	       cmd	=> 'lcg-ls',
	       opts	=> ['-l'],
             };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  map { $self->{MAP}{$_}++ } @fields;
  return $self;
}

sub Protocol { return 'srmv2'; }

sub parse
{
# Parse the lcg-ge-checksum output.
# Returns a hashref with all the fields parsed. Note that the format of the command
# and the order of the fields in @fields are tightly coupled.
  my ($self,$ns,$r,$file) = @_;
# return an empty hashref instead of undef if nothing is found, so it can
# still be dereferenced safely.
  my $result = {};
  foreach ( @{$r->{STDOUT}} )
  {
    my $x;
    chomp;
    m%.*Checksum: ([\dabcdef]+) \((\S+)\)%;
    $x->{checksum_value} = $1;
    $x->{checksum_type} = $2;
    $result = $x;
  }
  return $result;
}

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
