package PHEDEX::Web::API::Bounce;
use warnings;
use strict;
use PHEDEX::Web::Util;

=pod

=head1 NAME

PHEDEX::Web::API::Bounce - simple debugging call

=head2 bounce

Return the URL OPTIONS as a hash, so you can see what the server has done
to your request. Useful only for debugging.

=cut

sub duration { return 0; }
sub invoke { return bounce(@_); }
sub bounce
{
  my ($self,$core,%args) = @_;
  return { Bounce => \%args };
}

1;
