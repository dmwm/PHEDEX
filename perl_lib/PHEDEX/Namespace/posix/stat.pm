package PHEDEX::Namespace::posix::stat;
# Implements the 'stat' function for posix access
use strict;
use warnings;

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
	       cmd	=> 'stat',
	       opts	=> ['--format=%A:%u:%g:%s:%Y'],
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
  my ($self,$ns,$r) = @_;

# return an empty hashref instead of undef if nothing is found, so it can
# still be dereferenced safely.
  $r = {};
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
  print 'Return (',join(',',@fields),")\n";
}

1;
