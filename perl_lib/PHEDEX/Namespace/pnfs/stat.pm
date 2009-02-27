package PHEDEX::Namespace::pnfs::stat;
# Implements the 'stat' function for pnfs dump access
use strict;
use warnings;
use Time::Local;

our @ISA = qw(Exporter);
our @EXPORT = qw (); # export nothing by default
our @EXPORT_OK = qw( parse_pnfsdump );

our @fields = qw / access uid gid size mtime /;
sub new
{
  my ($proto,$h) = @_;
  my $csl_file = $h->{INPUT_FILE};
  my $class = ref($proto) || $proto;
  my $self = {
               cmd      => 'stat_pnfs_dump',
               opts     => [ $csl_file ],
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
# return an empty hashref instead of undef if nothing is found, so it can
# still be dereferenced safely.
  $r = {} unless defined $r;
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
