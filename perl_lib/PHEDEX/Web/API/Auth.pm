package PHEDEX::Web::API::Auth;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::Auth - show authentication state and abilities

=head1 DESCRIPTION

Serves the requesting user's authentication state.  May also be used
to authenticate using username and password, see L<below|"Password authentication">.

=head2 Options

  ability       authorization ability.  If passed then the nodes (from TMDB)
                that the user is allowed to use "ability" for are returned.
  require_cert  if passed then the call will die if the user is not
                authenticated by certificate

=head2 Output

Serves data in the following structure

  <auth>
     <role/>
     <role/>
     ...
     <node/>
     <node/>
     ...
  </auth>
   ...

=head3 <auth> attributes

 state   : the authentication state (cert|passwd|failed)
 dn      : the user's distinguished name
 ability : the ability that authorized nodes were requested for (see options)

=head3 <role> attributes

 name  : the name of the role
 group : the group (or site) associated with the role

=head3 <node> attributes

 name : the name of the node
 id   : the id of the node

=head2 Password authentication

Besides showing your current authentication status, the "auth" API can
also create an authentication cookie based on a user's SiteDB username
and password.  To do this, the client must HTTP POST the following
parameters to the "auth" API.

  SecModLogin   username for password authentication
  SecModPwd     password for password authentication

These parameters must be used together and the spelling must be exactly
as above (mixed cases).  Do not use HTTP GET to send these parameters,
sending a password via GET is insecure and the request will be
rejected.

If the username and password are correct, the API will respond with an
HTTP cookie in the header representing an authentication session.
Future requests to "auth" containing this cookie will show the current
authentication state and privileges allowed to the client using this
cookie.  Other APIs may accept this authentication cookie for their
use.

=cut

sub duration { return 0; }
sub need_auth { return 1; }
sub invoke { return auth(@_); }
sub auth
{
  my ($core,%args) = @_;

  $core->{SECMOD}->reqAuthnCert() if $args{require_cert};  
  my $auth = $core->getAuth($args{ability});

  # get $human_name
  my $human_name;
  my $first_name = $core->{SECMOD}->getForename();
  my $last_name = $core->{SECMOD}->getSurname();
  if ($first_name and $last_name)
  {
    $human_name = $first_name . ' ' . $last_name;
  }
  elsif ($first_name)
  {
    $human_name = $first_name;
  }
  elsif ($last_name)
  {
    $human_name = $last_name;
  }
    
  # make XML-able data structure from our data
  my $obj = { 'state' => $auth->{STATE},
	      'dn' => $auth->{DN},
	      'ability' => $args{ability},
              'human_name' => $human_name
	  };

  $obj->{'username'} = $core->{SECMOD}->getUsername() if $core->{SECMOD}->getUsername();

  foreach my $role (keys %{$auth->{ROLES}}) {
      foreach my $group (@{$auth->{ROLES}->{$role}}) {
	  $obj->{role} ||= [];
	  push @{$obj->{role}}, { name => $role, group => $group }
      }
  }

  foreach my $node (keys %{$auth->{NODES}}) {
      $obj->{node} ||= [];
      push @{$obj->{node}}, { name => $node,
			      id => $auth->{NODES}->{$node} };
  }

  return { auth => [ $obj ] };
}

1;
