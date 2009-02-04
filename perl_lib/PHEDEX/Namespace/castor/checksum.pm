package PHEDEX::Namespace::castor::checksum;
# Implements the 'checksum' function for castor access
use strict;
use warnings;
use base 'PHEDEX::Namespace::castor::Common';

our @fields = qw / tape_name checksum_type checksum_value is_migrated /;
sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
	       cmd	=> 'nsls',
	       opts	=> ['-T','--checksum']
	     };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  map { $self->{MAP}{$_}++ } @fields;
  return $self;
}

sub execute { (shift)->SUPER::execute(@_,'checksum'); }

sub parse
{
# Parse the checksum output. Each file is cached as it is seen. Returns the last
# file cached, which is only useful in NOCACHE mode!
  my ($self,$ns,$r,$dir) = @_;
  my $result = {
		 tape_name	=> undef,
		 checksum_type	=> undef,
		 checksum_value	=> undef,
		 is_migrated	=> 0,
	       };
  foreach ( @{$r->{STDOUT}} )
  {
    my (@a,$x,$file);
    chomp;
    @a = split(' ',$_);
    scalar(@a) == 11 or next;
    $x->{tape_name} = $a[3];
    $x->{checksum_type}  = $a[8];
    $x->{checksum_value} = $a[9];
    if  ( $x->{tape_name} =~ m%^-$% ) { $x->{is_migrated} = 0; }
    else			      { $x->{is_migrated} = 1; }
    $file = $a[10];

    $ns->{CACHE}->store('checksum',"$dir/$file",$x);
    $result = $x;
  }
  return $result;
}

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
