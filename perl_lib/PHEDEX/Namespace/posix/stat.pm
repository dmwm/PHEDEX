package PHEDEX::Namespace::posix::stat;
# Implements the 'stat' function for posix access
use strict;
use warnings;

our @fields = qw / perm uid gid size mtime /;
sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my $self = {
	       cmd	=> 'stat',
	       opts	=> ['--format=%A:%u:%g:%s:%Y'],
             };
  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;
  return $self;
}

sub parse_stat
{
# Parse the stat output. Assumes the %A:%u:%g:%s:%Y format was used. Returns
# a hashref with all the fields parsed
  my ($self,$ns,$r) = @_;
  foreach ( @{$r->{STDOUT}} )
  {
    chomp;
    my @a = split(':',$_);
    if ( scalar(@a) == 5 )
    {
      foreach ( @fields ) { $r->{$_} = shift @a; }
    }
  }
  return $r;
}

sub Help
{
  return "Return (" . join(',',@fields) . ") for a file\n";
}

1;
