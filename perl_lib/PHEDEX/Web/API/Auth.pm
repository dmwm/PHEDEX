package PHEDEX::Web::API::Auth;
use warnings;
use strict;
use PHEDEX::Web::Util;

=pod
=head1 NAME

PHEDEX::Web::API::Auth - check or enforce authentication

=head2 auth

Return a hash of the users' authentication state. The hash contains keys for
the STATE (cert|passwd|failed), the DN, the ROLES (from sitedb) and the
NODES (from TMDB) that the user is allowed to operate on.

if 'require_cert' is passed in the input arguments with a non-zero value,
the call will die unless the user is authenticated with a certificate.

=cut

sub invoke { return auth(@_); }
sub auth
{
  my ($self,$core,%args) = @_;

  $core->{SECMOD}->reqAuthnCert() if $args{require_cert};
  return $core->getAuth();
}

1;
