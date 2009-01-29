package PHEDEX::Namespace::castor::checksum;
# Implements the 'checksum' function for castor access
use strict;
use warnings;
use base 'PHEDEX::Namespace::castor::Common';

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my $self = {
	       cmd	=> 'nsls',
	       opts	=> ['-T','--checksum']
	     };
  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;
  return $self;
}

sub execute { (shift)->SUPER::execute(@_,'checksum'); }

sub parse_checksum
{
# Parse the checksum output. Each file is cached as it is seen. Returns the last
# file cached, which is only useful in NOCACHE mode!
  my ($self,$ns,$r,$dir) = @_;
  my $result;
  foreach ( @{$r->{STDOUT}} )
  {
    my (@a,$x,$file);
    chomp;
    @a = split(' ',$_);
    scalar(@a) == 11 or next;
    $x->{tape_name} = $a[3];
    $x->{checksum_type}  = $a[8];
    $x->{checksum_value} = $a[9];
    $file = $a[10];

    $ns->{CACHE}->store('checksum',"$dir/$file",$x);
    $result = $x;
  }
  return $result;
}

sub Help
{
  return "Return tape_name, checksum_type, and checksum_value for a file\n";
}

1;
