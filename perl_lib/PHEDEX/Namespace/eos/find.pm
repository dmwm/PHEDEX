package PHEDEX::Namespace::eos::find;
# Provides size and checksum as returned by the  'eos.select find' command.
use strict;
use warnings;
use Time::Local;
use File::Basename;
use base 'PHEDEX::Namespace::eos::Common';

# @fields defines the actual set of attributes to be returned
our @fields = qw / size checksum_type checksum_value /;
sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
	       cmd	=> 'eos.select',
	       opts	=> ['find', '-f', '--size', '--checksum'],
             };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  map { $self->{MAP}{$_}++ } @fields;
  return $self;
}

sub execute { (shift)->SUPER::execute(@_,'find'); }

sub parse
{
#Assumes the following output format:
#find -f --size --checksum /some/lfn
#path=/some/lfn size=12345 checksum=70dd0504
# checksum_type=adler32 is hardcoded, since 'eos find' does not tell us the checksum type.

  my ($self,$ns,$r,$dir) = @_;
  my $result;
  my $file;
# return an empty hashref instead of undef if nothing is found, so it can
# still be dereferenced safely.
  $r = {} unless defined $r;
  foreach ( @{$r->{STDOUT}} )
  {
    my ($x);
    chomp;
    m%^path=(\S+) size=(\d+) checksum=(\S+)$%
        or next;
    $file = basename $1;
    $x->{size} = $2;
    $x->{checksum_type} = "adler32";
    $x->{checksum_value} = $3;

    $ns->{CACHE}->store('find',"$dir/$file",$x);

    $result = $x;
  }
  return $result;
}

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
