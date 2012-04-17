package PHEDEX::Namespace::rfio::stat;
# Implements the 'stat' function for rfio access
use strict;
use warnings;
use Time::Local;

our @fields = qw / access uid gid size mtime /;
sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
	       cmd	=> 'rfstat',
	       opts	=> [],
             };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  return $self;
}

sub parse
{
# Parse the stat output. Returns a hashref with all the fields parsed
  my ($self,$ns,$r,$file) = @_;
  foreach ( @{$r->{STDOUT}} )
  {
    chomp;
    if ( m%^Protection\s+:\s+(\S+)\s+% )  { $r->{perm} = $1; next; }
    if ( m%^Gid\s+:\s+(\S+)\s+% )         { $r->{gid}  = $1; next; }
    if ( m%^Uid\s+:\s+(\S+)\s+% )         { $r->{uid}  = $1; next; }
    if ( m%^Size \(bytes\)\s+:\s+(\d+)% ) { $r->{size} = $1; next; }
    if ( m%^Last modify\s+:\s+(.+)$% )
    {
      my (@t,$t,%h);
      %h = ( Jan => 0, Feb => 1, Mar => 2, Apr => 3, May =>  4, Jun =>  5,
	     Jul => 6, Aug => 7, Sep => 8, Oct => 9, Nov => 10, Dec => 11 );
      $t = $1;
      $t =~ m%^\S+\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d+)$%;
      @t = ( $5, $4, $3, $2, $h{$1}, $6 );
      $r->{mtime} = timelocal(@t);
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
