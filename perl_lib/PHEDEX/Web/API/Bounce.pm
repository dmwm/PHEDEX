package PHEDEX::Web::API::Bounce;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Bounce - simple data service debugging tool

=head2 DESCRIPTION

Return the URL OPTIONS as a hash, so you can see what the server has done
to your request. Useful only for debugging.

If one of the options is called 'die', then this call dies.

=cut

sub duration { return 0; }
sub invoke { return bounce(@_); }
sub bounce
{
  my ($core,%args) = @_;
  
  if (exists $args{'die'} && $args{'die'}) {
      die "error requested, dying\n";
  }
  return { Bounce => \%args };
}

1;
