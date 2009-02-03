package PHEDEX::Namespace::posix::delete;
# Implements the 'delete' function for posix access
use strict;
use warnings;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
# $self is an empty hashref because there is no external command to call
  my $self = {};
  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;
  return $self;
}

sub execute
{
# Deletes an array of files. Returns the difference between the number of
# files to be deleted and the number actually deleted. I.e. returns 0 for
# success, regardless of the number of files it is given
  my ($self,$ns,@files) = @_;
  return 0 unless @files;
  return scalar @files - unlink @files;
}

sub Help
{
# returns, does not print, the help message for this module.
  return <<EOH;
delete (unlink) a set of files. Returns the number of files _not_
deleted. This allows you to call it with an empty list and still make sense
of the return value
EOH
}

1;
