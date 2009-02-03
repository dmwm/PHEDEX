package PHEDEX::Namespace::castor::class;
# Implements the 'class' function for castor access
use strict;
use warnings;
use base 'PHEDEX::Namespace::castor::Common';

sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
	       cmd	=> 'nsls',
	       opts	=> ['--class']
	     };
  bless($self, $class);
  return $self;
}

sub execute { (shift)->SUPER::execute(@_,'class'); }

sub parse_class
{
# Parse the class output. Each file is cached as it is seen. Returns the last
# file cached, which is only useful in NOCACHE mode!
  my ($self,$ns,$r,$dir) = @_;
  my $result = {};
  foreach ( @{$r->{STDOUT}} )
  {
    my ($x,$file);
    chomp;
    m%^\s*(\d+)\s+(\S+)$% or next;
    $x->{class} = $1;
    $file = $2;

    $ns->{CACHE}->store('class',"$dir/$file",$x);
    $result = $x;
  }
  return $result;
}

sub Help
{
  return "Return the file-class\n";
}

1;
