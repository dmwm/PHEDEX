package PHEDEX::Namespace::castor::stat;
# Implements the 'stat' function for castor access
use strict;
use warnings;
use Time::Local;
use base 'PHEDEX::Namespace::castor::Common';

our @fields = qw / access uid gid size mtime /;
sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
	       cmd	=> 'nsls',
	       opts	=> ['-l']
	     };
  bless($self, $class);
  map { $self->{MAP}{$_}++ } @fields;
  return $self;
}

sub execute { (shift)->SUPER::execute(@_,'stat'); }

sub parse_stat
{
# Parse the stat output. Each file is cached as it is seen. Returns the last
# file cached, which is only useful in NOCACHE mode!
  my ($self,$ns,$r,$dir) = @_;
  my $result;
  
  foreach ( @{$r->{STDOUT}} )
  {
    my ($x,$file,@t,%h,$M,$d,$y_or_hm,$y,$h,$m);
    chomp;
    m%^(\S+)\s+\d+\s+(\S+)\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$%
	or next;
    $x->{access} = $1;
    ($x->{uid},$x->{gid}) = (getpwnam($2))[2,3];
    $x->{size} = $3;

    %h = ( Jan => 0, Feb => 1, Mar => 2, Apr => 3, May =>  4, Jun =>  5,
	   Jul => 6, Aug => 7, Sep => 8, Oct => 9, Nov => 10, Dec => 11 );
    $M = $h{$4};
    $d = $5;
    $y_or_hm = $6;
    $file = $7;
    if ( $y_or_hm =~ m%(\d+):(\d+)% ) { $h = $1; $m = $2; }
    else                              { $y = $y_or_hm; }
    @t = ( 0, $m, $h, $d, $M, $y );
    $x->{mtime} = timelocal(@t);
    $ns->{CACHE}->store('stat',"$dir/$file",$x);
    $result = $x;
  }
  return $result;
}

sub Help
{
  return "Return (" . join(',',@fields) . ")\n";
}

1;
