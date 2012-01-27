package PHEDEX::Web::FrontendAuth;
use strict;
use DBI;
use Data::Dumper;

sub new {
  my $class = shift;
  my $options = shift;
  my $self = {};
  bless ($self, $class);

  my @settable = qw(DBNAME DBUSER DBPASS HEADERS_IN);
  $self->{DBNAME} = undef;
  $self->{DBUSER} = undef;
  $self->{DBPASS} = undef;
  $self->{DBHANDLE} = undef;

  while( my ($opt,$val) = each %$options) {
    warn "No such option: $opt" if ! grep (/^$opt$/,@settable);
    $self->{$opt} = $val;
  }

  return $self;
}

sub init {
  my ($self,$core) = @_;
  my ($r,$headers);
  if ( $r = $core->{REQUEST_HANDLER} ) {
    $headers = $r->headers_in();
  } else {
    $headers = $self->{HEADERS_IN} || $core->{HEADERS_IN};
  }
  foreach ( %{$headers} ) {
    m%^cms%i or m%^ssl_client_%i or next;
    $self->{HEADER}{lc $_} = $headers->{$_};
  }

  $self->{AUTHNSTATE} = 'failed';
  my $AuthStatus = $self->{HEADER}{'cms-auth-status'} || '';
  if ( $AuthStatus eq 'OK' ) {
    my $AuthNMethod = $self->{HEADER}{'cms-authn-method'};
    if ( $AuthNMethod eq 'X509Cert' ||
         $AuthNMethod eq 'X509Proxy' ) {
      $self->{AUTHNSTATE} = 'cert';
    } elsif ( $AuthNMethod eq 'HNLogin' ) {
      $self->{AUTHNSTATE} = 'passwd';
    } else {
      $self->{AUTHNSTATE} = 'none';
    }
  }

  my $connstr = "DBI:Oracle:" . $self->{DBNAME};

  eval {
      $self->{DBHANDLE} = DBI->connect($connstr, $self->{DBUSER}, $self->{DBPASS},
                                       {'AutoCommit' => 0,
                                        'RaiseError' => 1,
                                        'PrintError' => 0});
  };
  die  "Could not connect to SiteDB" if $@;

  $self->{ROLES}=$self->getRoles();
  $self->{USERNAME}=$self->{HEADER}{'cms-authn-login'};
  $self->{USERID} = $self->getIDfromDN($self->getDN());
  $self->getUserInfoFromID($self->{USERID});

  return 1;
}

sub isSecure {
  return 1 if (shift)->{HEADER}{'cms-auth-status'};
  return 0;
}

sub isAuthenticated {
  my $authnstate = (shift)->{AUTHNSTATE};
  return 1 if ( $authnstate eq 'cert' || $authnstate eq 'passwd' );
  return 0;
}

sub isCertAuthenticated {
  return 1 if (shift)->{AUTHNSTATE} eq 'cert';
  return 0;
}

sub isPasswdAuthenticated {
  return 1 if (shift)->{AUTHNSTATE} eq 'passwd';
  return 0;
}

sub isKnownUser {
  my $self = shift;
  return 1 if defined $self->{HEADER}{'cms-authn-name'};
  return 1 if defined $self->{HEADER}{'cms-authn-login'};
  return 0;
}

sub hasRole {
  my $self = shift;
  my $role = lc shift;
  my $scope = shift;

  return 0 if ! exists $self->{ROLES}->{$role};
  return 1 if ! defined $scope or grep(/^$scope$/,@{$self->{ROLES}->{$role}});
  return 0;
}

sub getAuthnState { return (shift)->{AUTHNSTATE}; }
sub getID         { return (shift)->{USERID}; }
sub getDN         { return (shift)->{HEADER}{'cms-authn-dn'}; }
sub getBrowserDN  { return (shift)->{HEADER}{ssl_client_s_dn}; }
sub getCert       { return (shift)->{HEADER}{ssl_client_cert}; }
sub getUsername   { return (shift)->{HEADER}{'cms-authn-name'}; }
sub getSurname    { return (shift)->{USERSURNAME}; }
sub getForename   { return (shift)->{USERFORENAME}; }
sub getEmail      { return (shift)->{USEREMAIL}; }

sub getRoles {
 my $self = shift;

 return $self->{ROLES} if $self->{ROLES};
  my ($roles,$name,$group);
  foreach ( keys %{$self->{HEADER}} ) {
    next unless m%^cms-authz-(\S+)$%;
    $name = lc $1;
    $name =~ s%-% %g;
    $group = lc $self->{HEADER}{$_};
    $group =~ s%^group:%%; # TW Slightly dodgy, mixing site and group namespaces
    $group =~ s%^site:%%;  # TW ...but we're probably safe there!
    $roles->{$name} = [] unless defined $roles->{$name};
    push @{$roles->{$name}}, $group;
  }
  return $self->{ROLES} = $roles;
}

sub DESTROY { }

sub urlencode {
  (my $str = shift) =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  return $str;
}

sub urldecode {
  (my $str = shift) =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  return $str;
}

# @params:  a role and a site
# @return:  list of usernames
sub getUsersWithRoleForSite {
    my ($self, $role, $site) = @_;
    my $sql = qq{ select c.id, c.surname, c.forename, c.email,
                         c.username, c.dn
                    from contact c
                    join site_responsibility sr on sr.contact = c.id
                    join role r on r.id = sr.role
                    join site s on s.id = sr.site
                   where r.title = ? and s.name = ? };
    my $sth = $self->{DBHANDLE}->prepare($sql);
    $sth->execute($role,$site);
    my @users;
    while (my $user = $sth->fetchrow_hashref()) {
        push @users, $user;
    }
    return @users;
}

# @params:  none
# @returns:  hash of site names pointing to array of phedex nodes
sub getPhedexNodeToSiteMap {
  my $self = shift;
  my $sql = qq { select n.name phedex_name, c.name cms_name
                 from phedex_node n
                 join site_cms_name_map sn on sn.site_id = n.site
                 join cms_name c on c.id = sn.cms_name_id };
  my $sth = $self->{DBHANDLE}->prepare($sql);
  $sth->execute();
  my %map;
  while (my ($node, $site) = $sth->fetchrow()) {
      $site = lc $site;
      $site =~ s%[^a-z0-9]+%-%g;
      $map{$node} = $site;
  }
  return %map;
}

# @param: user's DN
# @return: user's ID
sub getIDfromDN {
  my $self = shift;
  my $dn = shift;

  my $sth = $self->{DBHANDLE}->prepare("SELECT id FROM contact WHERE dn = ?");
  $sth->execute($dn);
  if(my $row = $sth->fetchrow_arrayref()) {
    return $row->[0];
  }
  return undef;
}

# retrieves additional user info fields like forename, surname, email
# @param: user ID
# @return: 1 for success, 0 for failure
sub getUserInfoFromID {
  my $self = shift;
  my $id = shift;

  return 0 if ! defined $id;
  my $sth = $self->{DBHANDLE}->prepare("SELECT surname,forename,email FROM contact WHERE id = ?");
  $sth->execute($id);
  if(my $row = $sth->fetchrow_arrayref()) {
    $self->{USERSURNAME} = $row->[0];
    $self->{USERFORENAME} = $row->[1];
    $self->{USEREMAIL} = $row->[2];
    return 1;
  }
  return 0;
}

sub reqAuthnCert {
  my $self = shift;
  return 1 if $self->isCertAuthenticated();
  die PHEDEX::Web::Util::http_error(401,"Certificate authentication required");
}

sub reqAuthnPasswd {
  my $self = shift;
  return 1 if $self->isPasswdAuthenticated();
  die PHEDEX::Web::Util::http_error(401,"Password authentication required");
}

1;
