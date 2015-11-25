package PHEDEX::Namespace::gfal::delete;
# Implements the 'delete' function for gfal access
use strict;
use warnings;

sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
	       cmd	=> 'gfal-rm',
	       opts	=> [],
             };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  return $self;
}

sub execute { die "Not yet implemented...\n"; (shift)->SUPER::execute(@_,'stat'); }

sub parse
{
  my ($self,$ns,$r,$file) = @_;

  $r = {};
  foreach ( @{$r->{STDOUT}} )
  {
    chomp;
    my @a = split(':',$_);
    if ( scalar(@a) == 5 )
    {
#     foreach ( @fields ) { $r->{$_} = shift @a; }
    }
  }
  return $r;
}

sub Help
{
  print "delete a file\n";
}

1;
