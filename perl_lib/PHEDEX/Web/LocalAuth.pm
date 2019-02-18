package PHEDEX::Web::LocalAuth;
use strict;
use DBI;
use Data::Dumper;
use Text::Unaccent;
use JSON::XS;

my ($ExtraNodes,$UID);

# NER: by design this class inherits from Core::DB (as all PHEDEX classes?)
# so even though I read from a local file, I have to also initialize the DBH.
sub new {
  my $class = shift;
  my $options = shift;
  my $self = {};
  bless ($self, $class);

  my @settable = qw(
                    DBNAME
                    DBUSER
                    DBPASS
                    HEADERS_IN
                    FILES_PATH
                    );
  $self->{DBNAME} = undef;
  $self->{DBUSER} = undef;
  $self->{DBPASS} = undef;
  $self->{DBHANDLE} = undef;
  $self->{FILES_PATH} = undef;
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
    $self->{HEADER}{lc $_} = unac_string('utf-8',$headers->{$_});
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
<<<<<<< HEAD
  } 
=======
  }
>>>>>>> no_sitedb

  if ( $self->{FILES_PATH} ) {
    # Assuming that all files live in the same location, we define
    # all required files here and check that they exist and are readable:
    my @required_files = qw(
                             site-names.json
                             site-responsibilities.json
                             people.json
                             group-responsibilities.json
                           );
    foreach ( map (($self->{FILES_PATH} . $_ ), @required_files)) {
      -r $_  or die "Could not read file $_";
<<<<<<< HEAD
      # FIXME: instead of dying print out a message that secmod can't be initialized 
    } 
=======
      # FIXME: instead of dying print out a message that secmod can't be initialized
    }
>>>>>>> no_sitedb
    # To minimize modification for the API changes, instead of passing every
    # file as configuration parameter, we add attribute for each file with a
    # full path based on the file name (e.g. SITE_NAMES for site-names.json):
    foreach ( @required_files) {
      my $file = $self->{FILES_PATH} . $_;
      s/-/_/;
      s/\.json$//;
      $self->{ uc $_} = $file;
    }
  } else {
    die "FILES_PATH undefined. Make sure that secmod-files-path is configured."
  }
  $self->{ROLES}=$self->getRoles();
  $self->{USERNAME}=$self->{HEADER}{'cms-authn-login'};
  $self->{DN}=$self->getUserInfoFromDN($self->getDN());
  # NRDEBUG: uncomment next two lines to dump secmod into a local file
  #PHEDEX::Web::Util::dump_debug_data_to_file($self, "secmod",
  #  "Dump secmod from  LocalAuth::init");
  return 1;
}

sub setTestNodes {
  my ($self,$nodes) = @_;
  $ExtraNodes = $nodes;
# $UID = 1540;
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
sub getUserLogin   { return (shift)->{HEADER}{'cms-authn-login'}; }
sub getEmail      { return (shift)->{USEREMAIL}; }

sub getRoles {
  my $self = shift;

  return $self->{ROLES} if $self->{ROLES};
  my ($roles,$name,$group,$key);
  foreach $key ( keys %{$self->{HEADER}} ) {
    next unless $key =~ m%^cms-authz-(.+)$%;
    $name = lc $1;
    $name =~ s%-% %g;
    $group = lc $self->{HEADER}{$key};
    $group =~ s%group:%:%g; # TW Slightly dodgy, mixing site & group namespaces
    $group =~ s%site:%:%g;  # TW ...but we're probably safe there!
    $roles->{$name} = [] unless defined $roles->{$name};
    foreach ( split(':',$group) ) {
      s%^\s+%%;
      s%\s+$%%;
      next unless m%\S+%;
      push @{$roles->{$name}}, $_;
    }
  }
  return $self->{ROLES} = $roles;
}

sub getSitesForUserRole
# Comparison for roles is case insensitive to work against headers style roles
{
  my ($self,$role) = @_;
  my $login = $self->getUserLogin();
  my %sitemap = $self->getPhedexNodeToSiteMap();
  my ($json_siteroles, $siteroles, @nodes, $entry);
  # Site-responsibilities format:
  # {"result": [ [ login, site, role], ...  ]}
  {
    open(F, $self->{SITE_RESPONSIBILITIES});
    local $/ = undef;
    $json_siteroles = <F>;
  }
  $siteroles = decode_json($json_siteroles);
  foreach $entry (@{$siteroles->{'result'}}) {
    if (${$entry}[0] eq $login && ((lc ${$entry}[2]) eq (lc $role ))) {
      foreach my $node (keys %sitemap) {
        if ($sitemap{$node} eq ${$entry}[1]) {
          push @nodes, $node;
        }
      }
    }
  }
  return \@nodes;
}

# Replacement for getSitesFromFrontendRoles:
# get sites the authenticated user can act on
# from a local dump of SiteDB site-names and site-responsibilities APIs
sub getSitesFromLocalRoles
{
  my $self = shift;
  my $login = $self->getUserLogin();
  my ($json_names, $names, $json_siteroles, $siteroles, @sites);
  # Site names map from a local file:
  {
    open( F, $self->{SITE_NAMES});
    local $/ = undef;
    $json_names = <F>;
  }
  $names = decode_json($json_names);
  # Site roles map from a local file:
  {
    open(F, $self->{SITE_RESPONSIBILITIES});
    local $/ = undef;
    $json_siteroles = <F>;
  }
  $siteroles = decode_json($json_siteroles);
  foreach my $role (@{$siteroles->{'result'}}) {
    if ( ${$role}[0] eq $login ) {
      foreach (@{$names->{'result'}}) {
        if ( ${$_}[0] eq 'phedex' && ${$_}[1] eq ${$role}[1] ) {
          push @sites,${$_}[2];
        }
      }
    }
  }
  return \@sites;
}

# The frontend site roles are being replaced by site-responsibilities dump,
# so this routine gets obsoleted:
#sub getSitesFromFrontendRoles
sub getSitesFromFrontendRolesObsolete
{
  my $self = shift;
  my ($roles,$role,%sites,@sites,$site,$sql,$sth);
  return if $self->{BASIC};
  $roles = $self->getRoles();
  $sql = qq{ select p.name phedex from phedex_node p
               join site s on p.site = s.id
               join site_cms_name_map cmap on cmap.site_id = s.id
<<<<<<< HEAD
               join cms_name c on c.id = cmap.cms_name_id 
=======
               join cms_name c on c.id = cmap.cms_name_id
>>>>>>> no_sitedb
               where lower(c.name) = ? };
  $sth = $self->{DBHANDLE}->prepare($sql);
  foreach $role ( values %{$roles} ) {
    foreach $site ( @{$role} ) {
      $site =~ s%-%_%g;
      $sth->execute($site);
      while ($_ = $sth->fetchrow_arrayref()) {
        $sites{$_->[0]}++;
      }
    }
  }
  @sites = keys %sites;
  return \@sites;
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

# This is used with Data Manager and Site Admin roles for email notifications
<<<<<<< HEAD
# Obsoleted implementation dependent on siteDB direct access 
=======
# Obsoleted implementation dependent on siteDB direct access
>>>>>>> no_sitedb
# @params:  a role and a site
# @return:  list of usernames
sub getUsersWithRoleForSiteObsolete {
  my ($self, $role, $site) = @_;
  return if $self->{BASIC};
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
# Map users/roles/sites based on local dumps of SiteDB or CRIC APIs
# @params:  a role and a site
# @return:  list of usernames
# This is usually used with Data Manager and Site Admin roles for email notifications
sub getUsersWithRoleForSite {
  my ($self, $role, $site) = @_;
  my ($json_siteroles, $siteroles, @users);
  {
    open(F, $self->{SITE_RESPONSIBILITIES});
    local $/ = undef;
    $json_siteroles = <F>;
  }
  $siteroles = decode_json($json_siteroles);
  # Get user info from people API dump:
  my ($json_people, $people, $contact);
  {
    open(F, $self->{PEOPLE});
    local $/ = undef;
    $json_people = <F>;
  }
  $people = decode_json($json_people);
  foreach my $entry (@{$siteroles->{'result'}}) {
    if ( $site eq ${$entry}[1]  &&  $role eq ${$entry}[2] ) {
      # look up user, assuming login name is unique:
      # and return user data in a format defined by a siteDB query:
      # select c.id, c.surname, c.forename, c.email,c.username, c.dn
<<<<<<< HEAD
      # retrieved with a fetchrow_hashref (see above the implementation 
      # of getUsersWithRoleForSiteObsolete )
      # The People API format is: 
      # {"desc": {"columns": ["username", "email", "forename", 
      # "surname", "dn", "phone1", "phone2", "im_handle"]}, "result": [
      # ...
      # ]} 
=======
      # retrieved with a fetchrow_hashref (see above the implementation
      # of getUsersWithRoleForSiteObsolete )
      # The People API format is:
      # {"desc": {"columns": ["username", "email", "forename",
      # "surname", "dn", "phone1", "phone2", "im_handle"]}, "result": [
      # ...
      # ]}
>>>>>>> no_sitedb
      foreach (@{$people->{'result'}}) {
        if (${$_}[0] eq ${$entry}[0]) {
          $contact = {
            'USERNAME'  => ${$_}[0],
            'EMAIL' => ${$_}[1],
            'FORENAME'  => ${$_}[2],
            'SURNAME' => ${$_}[3],
            'DN' => ${$_}[4],
          };
          push @users, $contact;
        }
      }
    }
<<<<<<< HEAD
  } # end of site responsibilities loop  
=======
  } # end of site responsibilities loop
>>>>>>> no_sitedb
  &PHEDEX::Web::Util::dump_debug_data_to_file(\@users, "site_contacts",
    "In getUsersWithRoleForSite: role = " . $role . " site = " . $site);
  return @users;
}

# @params:  none
# @returns:  hash of site names pointing to array of phedex nodes
# NR - it is actually other way around (as sub name  suggests)
# and it is a flat structure:
#          'T2_CH_CSCS' => 'CSCS',
#          'T0_CH_CERN_MSS' => 'CERN Tier-0',
#          'T0_CH_CERN_Export' => 'CERN Tier-0',

sub getPhedexNodeToSiteMap {
  my $self = shift;
  my ($json_names, $names);
  {
    open(F, $self->{SITE_NAMES});
    local $/ = undef;
    $json_names = <F>;
  }
  $names = decode_json($json_names);
  my %map;
  foreach (@{$names->{'result'}}) {
    if ( ${$_}[0] eq 'phedex' ) {
        $map{${$_}[2]} = ${$_}[1];
    }
  }
  foreach ( @{$ExtraNodes} ) {
    ($map{$_} = $_) =~ s%(_Buffer|_MSS)$%% unless $map{$_};
  }
  &PHEDEX::Web::Util::dump_debug_data_to_file(\%map, "sitemap",
    "Dump sitemap from getPhedexNodeToSiteMap ");
  return %map;
}
# NR: hope this can be obsoleted and we can live without replacement,
<<<<<<< HEAD
# as SiteDB ID is not exposed by any of its APIs. 
=======
# as SiteDB ID is not exposed by any of its APIs.
>>>>>>> no_sitedb
# @param: user's DN
# @return: user's ID
sub getIDfromDNObsoleted {
  my $self = shift;
  my $dn = shift;

  #return if $self->{BASIC};
  if ( $dn && $dn =~ m%(Data|Site)_T(0|1)$% && $UID ) {
    return $UID;
  }

  $dn =~ s%/CN=proxy%%g if $dn;

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

  #return if $self->{BASIC};
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

# retrieves additional user info fields like forename, surname, email
# from a local dump of SiteDB or CRIC people API) using DN matching.
# @param: user DN
# @return: 1 for success, 0 for failure
sub getUserInfoFromDN {
  my $self = shift;
  my $dn = shift;
  return 0 if ! defined $dn;
  my ($json_people, $people);
  {
    open(F, $self->{PEOPLE});
    local $/ = undef;
    $json_people = <F>;
  }
  $people = decode_json($json_people);
  foreach (@{$people->{'result'}}) {
<<<<<<< HEAD
    #die "Die in getUserInfoFromDN for undefined DN for user " . ${$_}[0] if not defined ${$_}[4];    
=======
    #die "Die in getUserInfoFromDN for undefined DN for user " . ${$_}[0] if not defined ${$_}[4];
>>>>>>> no_sitedb
    if ( (defined ${$_}[4]) && ${$_}[4] eq $dn ) {
      $self->{USEREMAIL} = ${$_}[1];
      $self->{USERSURNAME} = ${$_}[2];
      $self->{USERFORENAME} = ${$_}[3];
    }
  }
  if (defined $self->{USEREMAIL}){
    return 1;
    } else {
    return 0;
  }
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

<<<<<<< HEAD
# Getting rid of all direct access to the SiteDB 
=======
# Getting rid of all direct access to the SiteDB
>>>>>>> no_sitedb
sub getUsersWithRoleForGroupObsoleted {
  my ($self, $role, $group) = @_;
  return if $self->{BASIC};
  my $sql = qq{ select c.id, c.surname, c.forename, c.email,
		         c.username, c.dn, c.phone1, c.phone2
		    from contact c
		    join group_responsibility gr on gr.contact = c.id
		    join role r on r.id = gr.role
		    join user_group g on g.id = gr.user_group
		   where r.title = ? and g.name = ? };
  my $sth = $self->{DBHANDLE}->prepare($sql);
  $sth->execute($role, $group);
  my @users;
  while (my $user = $sth->fetchrow_hashref()) {
    push @users, $user;
  }
  return @users;
}

<<<<<<< HEAD
# NR FIXME:  allow this to break by not exiting for now.
# Needs to be replaced by reading from tghe local dumps of SiteDB/CRIC APIs,
# Will likely need a group-responsibilities API for this one. 
sub getUsersWithRoleForGroup {
  my ($self, $role, $group) = @_;
  die "NRDEBUG 2 STOP inside getUsersWithRoleForGroup for group $group";
  #return if $self->{BASIC};
  my $sql = qq{ select c.id, c.surname, c.forename, c.email,
		         c.username, c.dn, c.phone1, c.phone2
		    from contact c
		    join group_responsibility gr on gr.contact = c.id
		    join role r on r.id = gr.role
		    join user_group g on g.id = gr.user_group
		   where r.title = ? and g.name = ? };
  my $sth = $self->{DBHANDLE}->prepare($sql);
  $sth->execute($role, $group);
  my @users;
  while (my $user = $sth->fetchrow_hashref()) {
    push @users, $user;
  }
  &PHEDEX::Web::Util::dump_debug_data_to_file(\@users, "group_contacts",
  "In getUsersWithRoleForGroup: role = " . $role . " group = " . $group);
=======
# Map users/groups/roles using local secmod API dumps.
sub getUsersWithRoleForGroup {
  my ($self, $role, $group) = @_;
  #die "NRDEBUG 2 STOP inside getUsersWithRoleForGroup for group $group";
  my ($json_grouproles, $grouproles, @users);
  {
    open(F, $self->{GROUP_RESPONSIBILITIES});
    local $/ = undef;
    $json_grouproles = <F>;
  }
  $grouproles = decode_json($json_grouproles);
  # Get user info from people API dump:
  my ($json_people, $people, $contact);
  {
    open(F, $self->{PEOPLE});
    local $/ = undef;
    $json_people = <F>;
  }
  foreach my $entry (@{$grouproles->{'result'}}) {
    if ( $group eq ${$entry}[1]  &&  $role eq ${$entry}[2] ) {
      # look up user, assuming login name is unique:
      # and return user data in a format defined by a siteDB query:
      # select c.id, c.surname, c.forename, c.email,c.username, c.dn
      # retrieved with a fetchrow_hashref (see above the implementation
      # of getUsersWithRoleForSiteObsolete )
      # The People API format is:
      # {"desc": {"columns": ["username", "email", "forename",
      # "surname", "dn", "phone1", "phone2", "im_handle"]}, "result": [
      # ...
      # ]}
      foreach (@{$people->{'result'}}) {
        if (${$_}[0] eq ${$entry}[0]) {
          $contact = {
            'USERNAME'  => ${$_}[0],
            'EMAIL' => ${$_}[1],
            'FORENAME'  => ${$_}[2],
            'SURNAME' => ${$_}[3],
            'DN' => ${$_}[4],
          };
          push @users, $contact;
        }
      }
    }
  } # end of site responsibilities loop
>>>>>>> no_sitedb
  return @users;
}

1;
