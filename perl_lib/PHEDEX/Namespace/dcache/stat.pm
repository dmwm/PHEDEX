package PHEDEX::Namespace::dcache::stat;
# Implements the 'stat' function for dcache access
use strict;
use warnings;
use Time::Local;

# @fields defines the actual set of attributes to be returned
our @fields = qw / access uid gid size mtime /;
sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
# This shows the use of an external command to stat the file. It would be
# possible to do this with Perl inbuilt 'stat' function, of course, but this
# is just an example.
  my $self = {
	       cmd	=> 'ls',
	       opts	=> ['-l'],
             };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  map { $self->{MAP}{$_}++ } @fields;
  return $self;
}

sub parse
{
# Parse the stat output. Assumes the %A:%u:%g:%s:%Y format was used. Returns
# a hashref with all the fields parsed. Note that the format of the command
# and the order of the fields in @fields are tightly coupled.
  my ($self,$ns,$r,$file) = @_;

  my $result;
# return an empty hashref instead of undef if nothing is found, so it can
# still be dereferenced safely.
  $r = {} unless defined $r;
  foreach ( @{$r->{STDOUT}} )
  {
    my ($x,$file,@t,%h,$M,$d,$y_or_hm,$y,$h,$m);
    chomp;
    m%^(\S+)\s+\d+\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$%
        or next;
    $x->{access} = $1;
    $x->{uid} = getpwnam($2);
    $x->{gid} = getgrnam($3);
    $x->{size} = $4;

    %h = ( Jan => 0, Feb => 1, Mar => 2, Apr => 3, May =>  4, Jun =>  5,
           Jul => 6, Aug => 7, Sep => 8, Oct => 9, Nov => 10, Dec => 11 );
    $M = $h{$5};
    $d = $6;
    $y_or_hm = $7;
    $file = $8;
    if ( $y_or_hm =~ m%(\d+):(\d+)% ) { $h = $1; $m = $2; }
    else                              { $y = $y_or_hm; }
    @t = ( 0, $m, $h, $d, $M, $y );
    $x->{mtime} = timelocal(@t);
    $ns->{CACHE}->store('stat',"$file",$x);
    $result = $x;
  }
  return $result;
}

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
