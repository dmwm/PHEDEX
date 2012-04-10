package PHEDEX::Web::API::DBS;
use PHEDEX::Web::SQL;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::DBS - simple data service debugging tool

=head2 DESCRIPTION

Return a hash of DBS ids and names. Used in the next-gen website.

=cut

sub duration { return 12 * 3600; }
sub invoke { return dbs(@_); }
sub dbs
{
  my ($core,%h) = @_;
  my $r = PHEDEX::Web::SQL::getDBS($core, %h);
  return { dbs => $r };
}

1;
