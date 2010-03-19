package PHEDEX::BlockAllocator::SQL;

=head1 NAME

PHEDEX::BlockAllocator::SQL - encapsulated SQL for the Block Allocator
Checking agent. This module does not actually do anything useful yet,
but is nonetheless here as a placeholder for future development.

(Actually, we should probably just delete this, but I'm working on
documenation right now and not altering any code.)

=head1 SEE ALSO...

L<PHEDEX::Core::SQL|PHEDEX::Core::SQL>,
L<PHEDEX::BlockAllocator::Core|PHEDEX::BlockAllocator::Core>.

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::SQL';

use Carp;

our @EXPORT = qw( );
our (%params);
%params = (
	    DBH	=> undef,
	  );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = $class->SUPER::new(%params,@_);
  bless $self, $class;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

1;
