package PHEDEX::Namespace::srmv2lcg::stat;
# Implements the 'stat' function for srmv2 access
use strict;
use warnings;
use base 'PHEDEX::Namespace::srmv2::Common';
use Time::Local;

# @fields defines the actual set of attributes to be returned
our @fields = qw / access uid gid size checksum_type checksum_value locality /;
sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
# This shows the use of an external command to stat the file. It would be
# possible to do this with Perl inbuilt 'stat' function, of course, but this
# is just an example.
  my $self = {
	       cmd	=> 'lcg-ls',
	       opts	=> ['-l', '-b', '-Dsrmv2'],
             };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  map { $self->{MAP}{$_}++ } @fields;
  return $self;
}

sub execute { (shift)->SUPER::execute(@_,'stat'); }

sub parse
{
# Parse the stat output. Each file is cached as it is seen. Returns the last
# file cached, which is only useful in NOCACHE mode!
  my ($self,$ns,$r,$dir) = @_;
  
  foreach ( @{$r->{STDOUT}} )
  {
    my (@t,%h,$M,$d,$y,$h,$m,$s);
    chomp;
    if ( m%^\s*(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s*$% )
    {
      $r->{access} = $1;
      $r->{uid} = $3;
      $r->{gid} = $4;
      my $size = $5;
      $r->{locality} = $6;
      my $surl = $7;
      $r->{size} = $size if $surl =~ m%$dir%;
      next;
    }
    if ( m%^[\s\*]*Checksum:\s+(\S+)\s+\((\S+)\)\s*$% )
    {
      $r->{'checksum_value'} = $1;
      $r->{'checksum_type'} = $2;
      next;
    }
  }
  return $r;
}

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
