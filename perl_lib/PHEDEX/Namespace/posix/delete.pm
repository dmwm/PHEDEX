package PHEDEX::Namespace::posix::delete;
# Implements the 'delete' function for posix access
use strict;
use warnings;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my $self = {};
  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;
  return $self;
}

sub execute
{
# Deletes an array of files. Returns the difference between the number of
# files to be deleted and the number actually deleted. I.e. returns 0 for
# success
  my ($self,$ns,@files) = @_;
  return 0 unless @files;
  return scalar @files - unlink @files;
}

sub Help
{
  return "delete (unlink) a set of files. Returns the number of files\n" .
         "\t_not_ deleted. This allows you to call it with an empty list\n" .
	 "\tand still make sense of the return value\n";
}

1;
