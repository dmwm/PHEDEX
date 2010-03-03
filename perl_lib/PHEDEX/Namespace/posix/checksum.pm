package PHEDEX::Namespace::posix::checksum;
# Implements the 'checksum' function for posix access
use strict;
use warnings;

our @fields = qw / checksum_type checksum_value /;
sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
	       cmd	=> 'adler32', # 'md5sum',
	       opts	=> [], # ['-b']
	     };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  map { $self->{MAP}{$_}++ } @fields;
  return $self;
}

sub parse
{
# Parse the checksum output. Each file is cached as it is seen. Returns the last
# file cached, which is only useful in NOCACHE mode!

  my ($self,$ns,$r,$file) = @_;
  my $result = {
		 checksum_type	=> undef,
		 checksum_value	=> undef,
	       };
  foreach ( @{$r->{STDOUT}} )
  {
    my ($x);
    chomp;
    m%(^[\dabcdef]+)%;
    $x->{checksum_type}  = $self->{cmd};
    $x->{checksum_value} = $1;

    $ns->{CACHE}->store('checksum',$file,$x);

    $result = $x;
  }
  return $result;
}

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
