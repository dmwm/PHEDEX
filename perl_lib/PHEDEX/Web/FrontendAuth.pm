################################################################
# SecurityModule
#
# Version info: $Id: SecurityModule.pm,v 1.23 2010/08/20 13:48:40 wildish Exp $
################################################################
package PHEDEX::Web::FrontendAuth;

use IO::File;
use Crypt::CBC;
use MIME::Base64;
use Digest::MD5 qw(md5_base64);
use Data::Dumper;
use CGI qw(cookie param url_param redirect self_url url);
#use Carp;
use strict;

my $VERSION = '0.90';

sub new {
  my $class = shift;
  my $self = {};
  bless ($self, $class);

  $self->{LOGLEVEL} = -1; # hardwire it off
#  # read the config file and let command line given options override
#  # the config file supplied ones
#  if(exists $options->{CONFIG}) {
#    $self->{CONFIG} = $options->{CONFIG};
#    my $confopts = $self->_readConfigFile();
#    while( my ($opt,$val) = each %$confopts) {
#      $options->{$opt} = $val if ! exists $options->{$opt};
#    }
#  }
#
#  while( my ($opt,$val) = each %$options) {
#    next if ! grep (/^$opt$/,@settable);
#    $self->{$opt} = $val;
#    delete $options->{$opt};
#  }

  return $self;
}

sub init {
  my ($self,$core) = @_;
  my $r = $core->{REQUEST_HANDLER};
  my $headers = $r->headers_in();
  foreach ( %{$headers} ) {
    m%^cms%i or next;
    $self->{HEADER}{lc $_} = $headers->{$_};
  }

  $self->_log(5,"Initialization state: " . Dumper($self));

  $self->{AUTHNSTATE} = 'failed';
  my $AuthStatus = $self->{HEADER}{'cms-auth-status'};
  if ( $AuthStatus eq 'OK' ) {
    my $AuthNMethod = $self->{HEADER}{'cms-authn-method'};
    if ( $AuthNMethod eq 'X509Cert' ||
         $AuthNMethod eq 'X509Proxy' ) {
      $self->{AUTHNSTATE} = 'cert';
    } elsif ( $AuthNMethod eq 'HNLogin' ) {
      $self->{AUTHNSTATE} = 'cert';
    } else {
      $self->{AUTHNSTATE} = 'none';
    }
  }
  $self->{ROLES}=$self->_getRolesFromID();
  $self->{USERNAME}=$self->{HEADER}{'cms-authn-login'};
warn Data::Dumper->Dump([ $self ]);
  $self->_getUserInfoFromID($self->{USERID});

  return 1;
}

sub isSecure {
 die "Obsolete isSecure called\n";
}

sub isAuthenticated {
  my $self = shift;
  return 1 if $self->{'cms-auth-status'} == 'OK';
  return 0;
}

sub isCertAuthenticated {
  my $self = shift;
  return 1 if $self->{AUTHNSTATE} eq "cert";
  return 0;
}

sub isPasswdAuthenticated {
  my $self = shift;
  return 1 if $self->{AUTHNSTATE} eq "passwd";
  return 0;
}

sub isKnownUser {
    my $self = shift;
    return 1 if defined $self->getID();
    return 0;
}

sub hasRole {
  my $self = shift;
  my $role = shift;
  my $scope = shift;

  return 0 if ! exists $self->{ROLES}->{$role};
  return 1 if ! defined $scope or grep(/^$scope$/,@{$self->{ROLES}->{$role}});
  return 0;
}

sub reqAuthnPasswd {
  my $self = shift;

  if ( !$self->isSecure() ) {
    (my $red = $self->{CALLER_URL}) =~ s!^http:!^https:!;
    $self->_log(5, 'Redirecting to secure URL');
    print redirect($red);
  }

  return 1 if $self->isAuthenticated();
  $self->_showPasswdForm("password authentication required");
  exit(0);
}

sub reqAuthnCert {
  my $self = shift;

  if ( !$self->isSecure() ) {
    (my $red = $self->{CALLER_URL}) =~ s!^http:!^https:!;
    $self->_log(5, 'Redirecting to secure URL');
    print redirect($red);
  }

  return 1 if $self->isCertAuthenticated();

  if (ref($self->{REQCERT_FAIL_HANDLER}) eq "CODE") {
    &{$self->{REQCERT_FAIL_HANDLER}}($self->{AUTHNSTATE},$self->{USERDN});
    exit 1;
  }
  $self->_log(5, 'Redirecting to Cert Fail Handler '.$self->{REQCERT_FAIL_HANDLER});
  print redirect($self->{REQCERT_FAIL_HANDLER} ."?caller_url=" .
		 urlencode($self->{CALLER_URL}));
  exit 1;
}

sub getAuthnState {
  my $self = shift;

  return $self->{AUTHNSTATE};
}

sub getCookie {
  my $self = shift;
  return $self->{COOKIE};
}

sub getID {
  my $self = shift;
  return $self->{USERID};
}

sub getDN {
  my $self = shift;
  return $self->{HEADER}{'cms-authn-dn'};
}

sub getBrowserDN {
    my $self = shift;
    return $self->{SSL_CLIENT_S_DN};
}

sub getCert {
    my $self = shift;
    return $self->{SSL_CLIENT_CERT};
}

sub getUsername {
  my $self = shift;
  return $self->{USERNAME};
}

sub getSurname {
  my $self = shift;
  return $self->{USERSURNAME};
}

sub getForename {
  my $self = shift;
  return $self->{USERFORENAME};
}

sub getEmail {
  my $self = shift;
  return $self->{USEREMAIL};
}

sub getRoles {
  my $self = shift;
  return $self->{ROLES};
}

sub getErrMsg {
  my $self = shift;
  return $self->{ERRMSG};
}

sub setKeyValidTime {
  my $self = shift;
  $self->{KEYVALIDTIME} = shift;
}

sub setLogFile {
  die "Bleargle\n";
}

sub setLogLevel {
  my $self = shift;
  $self->{LOGLEVEL} = shift;
}

sub setPwdHandler {
  my $self = shift;
  $self->{PWDFORM_HANDLER} = shift;
}

sub setSignupHandler {
  my $self = shift;
  $self->{SIGNUP_HANDLER} = shift;
}

sub setReqCertFailHandler {
  my $self = shift;
  $self->{REQCERT_FAIL_HANDLER} = shift;
}

sub setCallerURL {
  my $self = shift;
  $self->{CALLER_URL} = shift;
}

sub DESTROY {

}

# CLASS METHODS

sub urlencode {
  (my $str = shift) =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  return $str;
}

sub urldecode {
  (my $str = shift) =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
  return $str;
}


############################################
# VIRTUAL METHODS TO BE IMPLEMENTED BY A
# SUBCLASS

# @params:  a role and a site
# @return:  list of usernames
sub getUsersWithRoleForSite {
  die "virtual function getUsersWithRoleForSite not implemented";
}

# @params:  a role and a group
# @return:  list of usernames
sub getUsersWithRoleForGroup {
  die "virtual function getUsersWithRoleForGroup not implemented";
}

# @params:  none
# @returns:  hash of site names pointing to array of phedex nodes
sub getPhedexNodeToSiteMap {
  die "virtual function getPhedexNodeToSiteMap not implemented";
}

# If argument keyid is given, fetches the appropriate key. If
# keyid is omitted, returns the a valid key from the DB (if no
# valid keys are found, a new one will be generated).
# @param: keyid  ID of key to be retrieved
# @return: 0 if ok, 1 if no such key in DB, 2 if key is too old
sub _getCipherKey {
  die "virtual function _getCipherKey not implemented";
}

# @param: user's ID
# @return: hash mapping roles to array of scopes
sub _getRolesFromID {
  my $self = shift;
  my ($roles,$name,$group);
  foreach ( keys %{$self->{HEADER}} ) {
    next unless m%^cms-authz-(\S+)$%;
    $name = $1;
    $group = $self->{HEADER}{$_};
    $group =~ s%^group:%%;
    $roles->{$name} = [] unless defined $roles->{$name};
    push @{$roles->{$name}}, $group;
  }
  return $roles;
}

# @param: short user name as used in passwd authentication
# @return: user's ID
sub _getIDfromUsername {
  die "virtual function _getIDfromUsername not implemented";
}

# @param: user's DN
# @return: user's ID
sub _getIDfromDN {
  die "virtual function _getIDfromUsername not implemented";
}

# @param: short user name as used in passwd authentication
# @return: password hash
sub _getUserPasswd {
  die "virtual function _getUserPasswd not implemented";
}

# @param: user ID
# @return: short user name
sub _getUsernameFromID {
  die "virtual function _getUsernameFromID not implemented";
}

# retrieves additional user info fields like forename, surname, email
# @param: user ID
# @return: 1 for success, 0 for failure
sub _getUserInfoFromID {
  my $self = shift;
  $self->{USERNAME} = $self->{'cms-authn-name'};
  $self->{USERSURNAME} = 
  $self->{USERFORENAME} = 
  $self->{USEREMAIL} = 'undefined (_getUserInfoFromID)';
}

############################################
# PRIVATE METHODS


sub _getOriginatorHash {
  my $self = shift;
  $self->_log(5,"_getOriginatorHash: REMOTE_ADDR=".$self->{REMOTE_ADDR});
  return  md5_base64($self->{REMOTE_ADDR},
		     $ENV{HTTP_USER_AGENT});
}

# very primitive configuration file reader
sub _readConfigFile {
  my $self = shift;

  my $conf={};

  open(CONF,"<$self->{CONFIG}") or die "Failed to open config file " . $self->{CONFIG};

  while(my $line = <CONF>) {
    next if $line =~ /^\s*#/ || $line =~ /^\s*$/;

    if( my ($opt,$val) = $line =~ m/^\s*([A-Z_]+)\s*=\s*([^\s]+)\s*$/) {
      $conf->{$opt} = $val;
    }
  }
  close CONF;
  $self->_log(5,"Config File $self->{CONFIG} contents: " . Dumper($conf));
  return $conf;
}

# Does authentication of a presented cookie. Also implements a
# logout feature by setting an obsolete cookie
#
# @return 1 for a correct cookie, 0 if an invalid cookie was found
#         also returns 1 if a "Logout" directive was found
sub _cookieAuthen {
  my $self = shift;
  my $cookie = shift;

  my ($state,$userid,$username,$orighash) = $self->_decryptCookie($cookie);
  #TODO test cookie creation time in addition to key validity time?
  if($state==0 && $orighash eq $self->_getOriginatorHash()) {
    $self->{AUTHNSTATE} = "passwd";
    $self->{USERID} = $userid;
    $self->{USERNAME} = $username;
    $self->{USERDN} = undef;
    return(1);
  }
  $self->_log(5,"_cookieAuthen: Failed: orighash=" . $self->_getOriginatorHash());

  if ($state == 2) {
    $self->{ERRMSG}="reauthentication";
    return(0);
  }

  $self->{ERRMSG}="invalid cookie";
  $self->_log(1,"INVALID COOKIE from .$self->{REMOTE_ADDR}: $cookie");
  return(0)
}

sub _log {
}


sub _createCryptKey {
  return Crypt::CBC->random_bytes(56);
}

# if $keyid is given the CIPHER will be initialised with
# the key matching this id (if available and still valid)
# @return: 0 if ok, 1 for invalid key, 2 for key too old,
#          3 for failure to create cipher object
sub _initCipher {
  my $self = shift;
  my $keyid = shift;

  my $rv;
  if ($keyid) {
    if ($rv = $self->_getCipherKey($keyid)) {
      if($rv == 1) {
	$self->{ERRMSG}="invalid cipher key ID $keyid";
	$self->_log(1,"WARNING: Failed to get cypher keys for ID $keyid");
      } elsif ($rv == 2) {
	$self->{ERRMSG}="old cipher key ID $keyid";
	$self->_log(3,"Refusing old cypher key (ID $keyid)");
      }
      return $rv;
    }
  } else {
    $self->_getCipherKey();
  }

  eval {
      $self->{CIPHER} = Crypt::CBC->new( -cipher => 'Blowfish',
					 -literal_key => 0, # should be set true, but incompat. with python SecMod
					 -key => $self->{CIPHERKEY},
					 -iv => "dummyabc",
					 -header      => 'none',
					 -blocksize => 8,
					 -keysize => 56,
					 -padding => 'standard'
					 );
  };
  if ($@ || !$self->{CIPHER}) {
      $self->_log(1,"Error: Failed to create cipher object: keyID $keyid, cipherkey:" .
		  Dumper($self->{CIPHERKEY}).", Crypt::CBC message:  $@");
      $self->{ERRMSG} = "failed to create cipher object";
      return 3;
  } else {
      return 0;
  }
}

# The random generated initialization vector is prepended to the
# encrypted text
sub _encrypt {
  my $self = shift;
  my $msg = shift;

  $self->_log(5,"msg to encrypt is >$msg< CIPHER: $self->{CIPHER}");
  #return "" if $msg == undef or $msg eq "";
  my $iv     = Crypt::CBC->random_bytes(8);
  $self->{CIPHER}->set_initialization_vector($iv);

  my $encr = $iv . $self->{CIPHER}->encrypt($msg);
  my $encr64 = encode_base64($encr);

  return $encr64;
}

sub _decrypt{
  my $self = shift;
  my $encr64 = shift;

  my $encr = decode_base64($encr64);
  my $iv = substr($encr,0,8,"");
  $self->{CIPHER}->set_initialization_vector($iv);

 my $decr;
  eval {
    $decr = $self->{CIPHER}->decrypt($encr);
  };
  if($@) {
    $self->_log(1,"Error: _decrypt: Failed to decrypt: $@");
    return undef;
  }

  return $decr;
}

#
#
# @return: (0,...) for ok, 1 for failed decryption or invalid key, 2 for key too old
#
sub _decryptCookie {
  my $self = shift;
  my $encrcookie = shift;

  my ($keyid,$encr) = $encrcookie =~ m/^([^|]+)\|(.+)$/s;
  return 1 if ! $keyid;

  my $rv;
  return $rv if ($rv = $self->_initCipher($keyid));

  my $decr = $self->_decrypt($encr);
  return 1 if ! $decr;
  my ($userid,$username,$orighash) = split(/\|/,$decr);

  my $dbusername = $self->_getUsernameFromID($userid);
  if ($username ne $dbusername) {
    $self->_log(1,"WARNING: cookie contained invalid id/username combination:"
		. " $userid/$username  (DB: $dbusername)");
    $self->{ERRMSG}="invalid id/username in cookie";
    return 1;
  }

  $self->_log(5,"_decryptCookie: $userid | $username | $orighash");
  return (0,$userid,$username,$orighash);
}

# prepares the cookie payload
sub _prepareCookie {
  my $self = shift;

  my $cleartxt = join("|",($self->{USERID},$self->{USERNAME},$self->_getOriginatorHash()));
  my $encr = $self->_encrypt($cleartxt);
  my $cookie =  $self->{KEYID} . "|" . $encr;

  return $cookie;
}


#
# Authenticate a user based on a password entered in the password form
#
# @return: 1 for authenticated, 0 for not authenticated
sub _passwordAuthen {
  my $self = shift;

  return 0 if $self->_initCipher();

  $self->{ERRMSG} = "";

  my $username = param("SecModLogin");
  my $pass = param('SecModPwd');

  my $dbpasswd = $self->_getUserPasswd($username);
  if(!$dbpasswd) {
      $self->{ERRMSG} = "Password verification failed";
      $self->_log(3,"Password verification failed for user $username");
      return 0;
  }
  my $hash = crypt($pass,substr($dbpasswd,0,2));
  $self->_log(5,"_passwordAuthen: user $username, pass: $hash,  dbpass: $dbpasswd");
  if ($dbpasswd eq $hash) {
    $self->{AUTHNSTATE} = "passwd";
    if ($self->{USERID} = $self->_getIDfromUsername($username)) {
      $self->{USERNAME} = $username;
      $self->{USERDN} = undef;
      # for now we use no 'expires' value -expires =>'',
      $self->{COOKIE} = cookie(-name => "SecMod",
			       -value => $self->_prepareCookie(),
			       -secure => 1
			      );
      $self->_log(4,"Successful password authentication by $username for ID $self->{USERID}");
      return(1);
    }

    $self->_log(3,"No ID known for user $username");
    $self->{ERRMSG} = "No ID known for user $username";
    $self->_showSignUpPage("username=$username");

    return(0);
  }

  $self->{ERRMSG} = "Password verification failed";
  $self->_log(3,"Password verification failed for user $username");
  # TODO: pass on amount of failed attempts in hidden field and redirect after certain
  # number of failures?
  return(0);
}

sub _showPasswdForm {
  my $self = shift;
  my $msg = shift;

  # get rid of any unwanted url parameters
  (my $url = $self->{CALLER_URL}) =~ s/[&?]SecModLogout=1//;
  $url =~ s/[&?]SecModPwd=1//;

  if (ref($self->{PWDFORM_HANDLER}) eq "CODE") {
    &{$self->{PWDFORM_HANDLER}}($url,$msg);
    #TODO: should pass all params except SecMod* through to the next page
    exit 1;
  }
  my $delim = $self->{PWDFORM_HANDLER} =~ /\?/ ? '&' : '?';
  $self->_log(5, 'Redirecting to password form '.$self->{PWDFORM_HANDLER});
  print redirect($self->{PWDFORM_HANDLER} ."${delim}caller_url=" .
		 urlencode($url) . "&msg=" . urlencode($msg));
  exit 0;

}

# @params: paramstring: string that will be appended to the redirection URL or passed
#          to the code ref
sub _showSignUpPage {
  my $self = shift;
  my $paramstring = shift;

  if (ref($self->{SIGNUP_HANDLER}) eq "CODE") {
    &{$self->{SIGNUP_HANDLER}}($self->{CALLER_URL},$paramstring);
    #TODO: should pass all params except SecMod* through to the next page
    exit 1;
  }
  $self->_log(5, 'Redirecting to signup form '.$self->{SIGNUP_HANDLER});
  print redirect($self->{SIGNUP_HANDLER} ."?caller_url=" .
		 urlencode($self->{CALLER_URL}) .
		 "&paramstring=" . urlencode($paramstring));
  exit 0;
}

# Adds newlines to a cert that is all in one line
sub _formatCert {
    my $self = shift;
    my $cert = shift;
    return undef if !defined $cert;
    my ($pre, $data, $post)
	= ($cert =~ /^(-+[A-Z ]+-+) (.*) (-+[A-Z ]+-+)$/);
    return "$pre\n" . join("\n", split(" ", $data)) . "\n$post\n";
}

# A default password form
sub _defaultPasswordForm {
  my $caller_url = shift;
  my $msg=shift;

  $caller_url =~ s!^http:!https:!;

  my $q = new CGI;

  print $q->header,$q->start_html;
  print $q->start_form("POST","$caller_url","application/x-www-form-urlencoded");
  print $q->h2("Default Password Dialog" . $msg);
  if ($msg) {
    print $q->h2("Error: " . $msg);
  } else {
    print $q->h2("Log in:");
  }
  $q->param('SecModPwd',"");
  print $q->p,"Login Name: ",$q->textfield('SecModLogin','',12,20);
  print $q->p,"Password: ",$q->password_field('SecModPwd','',20,30);
  print $q->p,$q->submit(-name=>'Submit',
			 -value=>'submit');

  my $sep = $caller_url =~ /\?/ ? "&" : "?";
  print "<br>" . $q->a({href => $caller_url . $sep . "SecModLogout=1"},"Return without logging in")
    . "<br>\n";


  print $q->endform;

  print $q->end_html;
  exit(0);
}

# A default page for failed certificate access
sub _defaultReqcertFailHandler {
  my $authnstate = shift;
  my $userdn = shift;

  my $q = new CGI;
  print $q->header,$q->start_html;
  print $q->h1("Default Page to handle certificate authentication failures");
  print "Access only with a valid certificate";
  if ($authnstate eq "passwd") {
    print " (and you are logged in via password)";
  } else {
    print $q->p,"Your Browser presented this certificate: " . $userdn if $userdn;
  }
  print $q->end_html;
  exit(0);

}

sub _defaultSignUpHandler {
  my $caller_url = shift;
  my $paramstring = shift;

  my $q = new CGI;
  print $q->header,$q->start_html;
  print $q->h1("Default sign up handler page");
  print "Your configuration does not define a custom handler.";
  print "<br>This page should allow you to sign up to the CMS web services.";
  print "<hr>Your user data is:<br>$paramstring\n";

  #print "<br>" . $q->a({href => $caller_url},"Return");
  print $q->end_html;
  exit(0);
}

1;


=pod

=head1 NAME

SecurityModule.pm - Web Security Module

=head1 SYNOPSIS

Note: This applies specifically to the MySQL implementation. There is also
a SecurityModule::SQLite implementation.

  use SecurityModule::MySQL;
  $sec = new SecurityModule::MySQL({CALLER_URL => $myurl,
				    CONFIG => "/etc/sec/SecMod.conf";
				    LOGLEVEL => 5,
				    KEYVALIDTIME => 7200,
				    PWDFORM_HANDLER => \&myPasswordForm
				   });

  $ret = $sec->init(); # returns 0 in case of failure

  $errmsg = $sec->getErrMsg(); # returns error message

  # if getCookie() returns a defined value, your page needs to make
  # sure that this cookie will be set using CGI.pm's
  # header(-cookie => $cookie ) command
  if( ($cookie=$sec->getCookie) ) {
    print header(-cookie => $cookie );
  } else {
    print header();
  }


  # Access to authentication / authorization information
  $state = $sec->getAuthnState(); # returns (failed | cert | passwd)
  $user_dn = $sec->getDN(); # returns user's distinguished name
  $roles = $sec->getRoles(); # returns a hash of roles, each role mapping to a
                             # list of scopes


  # Protecting functions: reqAuthnCert() and reqAuthnPasswd()
  sub my_certificate_protected_function {
    $sec->reqAuthnCert();
    ...
  }
  sub my_password_protected_function {
    $sec->reqAuthnPasswd();
    ...
  }

=head1 DESCRIPTION

The SecurityModule handles authentication and authorization to a web site. Users
are identified by a certificate loaded in their browser or by a previously
set cookie that was issued upon a successful password authentication.

Certificate based authentication is the strongest authentication type,
so functions protected by the reqAuthnPasswd() method will allow
access to certificate authenticated users, but reqAuthnCert() will deny
access to password authenticated users.

The SecurityModule was written for a setup where a B<remote Proxy> mediates access
to a number of backend servers. The remote proxy handles
the SSL authentication and is required to set the following request headers to
the values of the respective environment variables for this request:

B<SSL_CLIENT_VERIFY>,
B<SSL_CLIENT_S_DN>,
B<HTTPS>.

On the backend servers these must be available as environment variables of identical names
except for the prefix B<HTTP_>, e.g. B<HTTP_SSL_CLIENT_S_DN>.

Since all backend servers are hidden behind the reverse proxy, an authentication
cookie is set restrictively to only be sent back to the issueing server. The
necessary translation for the proxy is handled transparently by apache's mod_proxy
module (needs E<gt>= apache-2.2).

The SecurityModule can also be run without a reverse proxy in pure SSL mode if
the REVPROXY directive is left out or set to 0.

=head2 Initialization

Arguments which can be passed to the constructor:

=over 4

=item *

B<CALLER_URL>:  URL of the current page that was invoked by
the browser, i.e. it must contain the URL which the reverse proxy got
before redirecting to the backend server.

=item *

B<CONFIG>: Filename of a configuration file. The file must contain "option = value"
lines as in this example:

   LOGFILE = /tmp/SecMod.log
   REVPROXY = 137.138.65.249,137.138.65.224
   LOGLEVEL = 5
   KEYVALIDTIME = 1500
   # Comments and empty lines are allowed
   DBHOST = localhost
   DBPORT = 3306
   DBNAME = secmod
   DBUSER = smwriter
   DBPASS = mypasswd
   REQCERT_FAIL_HANDLER = https://localhost/bclear/testSecMod/nopermission
   PWDFORM_HANDLER = https://localhost/bclear/testSecMod/passform

B<Note>: The configuration options specified in the constructor will override
any options specified in the configuration file.

=item *

B<REVPROXY>: comma separated list of the IP addresses of allowed
reverse proxies.  If this directive is ommitted, the module will work
in non reverse proxy mode. If defined and the module receives a
connection from a not allowed host, a high priority warning is issued
to the log.

=item *

B<KEYVALIDTIME>: Validity time in seconds of generated keys

=item *

B<PWDFORM_HANDLER>: URL or reference to a function generating a
password page. If a function reference is given, two values will be
passed into the function: The URL of the present page (so we can get
back) and a status message describing why the password form was
called. If an URL is given, the two values will be passed using a
query string (?caller_url=...&msg=...) in the redirection.

        Status messages: password authentication required
                         reauthentication
                         invalid cookie

item *

B<SIGNUP_HANDLER>: URL or reference to a function implementing a sign up
page. Users which are not registered in the system (internally: users with
no entry in the contacts table of SiteDB), but whose certificate was
accepted by the web server are redirected to the sign up page. The same applies
to users who have a valid login/password (since this information
is synced from an external source), but are not registered with SiteDB yet.

item *

B<STRICT_SIGNUP>: By default any unregistered user will be directed to
the SIGNUP_HANDLER (see above).  If this option is false then the
redirection is skipped, and it is up to the application to determine
what to do with authenticated users not known to the system.

=item *

B<REQCERT_FAIL_HANDLER>: URL or reference to a function to call when a page secured by
reqAuthnCert() is encountered and the client is not certificate authenticated.
Typically, to display some diagnostic message.

=item *

B<LOGFILE>: Filename of the logfile. If this is undefined, all log messages
are written to STDERR, i.e. they should end up in the web server's error log.

=item *

B<LOGLEVEL>: Integer value from 0-5

      0: no log messages at all
      1: error and security relevant messages only
      3: Logs password authentications (standard log level)
      5: debugging messages

=item *

For the MySQL implementation you can also supply the DB connection parameters
B<DBHOST, DBPORT, DBNAME, DBUSER, DBPASS>

=item *

For the SQLite implementation you only need to supply a B<DBFILE> parameter
with the location of the data base file.

=back




=head2 Convenience Functions for condition tests

these functions can be used to formulate conditions easily

=over 4

=item *

isSecure(): returns 1 if connection is SSL secured, 0 otherwise

=item *

isAuthenticated(): returns 1 if user is authenticated either by certificate or
by password/cookie, 0 otherwise

=item *

isCertAuthenticated(): returns 1 if user is authenticated by SSL/certificate, 0
otherwise

=item *

isPasswdAuthenticated(): returns 1 if user is authenticated by password, 0 otherwise

=item *

hasRole(role) or hasRole(role,scope): returns 1 if user is authorized to have the given role
or the given role/scope pair., 0 otherwise

=back

=head2 Functions to retrieve current user's information

These functions can be used to retrieve additional information about a user

=over 4

=item *

getID(): returns the user ID. This is the principal authentication token

=item *

getDN(): returns the associated distinguished name

=item *

getUsername(): returns the short name used as the login name

=item *

getSurname(), getForename(): normal human name of the user

=item *

getEmail(): returns user's email

=back

=head2 Functions to retrieve other user's information

=item *

getUsersWthRoleForSite(role, site), getUsersWithRoleForGroup(role, group):
Retrieves an array of hashrefs with user information of authorized users

=back

=head2 Other functions

=item * 

getPhedexNodeToSiteMap:
Returns a hash of phedex node => site

=back


=head2 Calling the password form via a web page 'Login' link:

You can pass B<SecModPwd=1> as a GET variable to any page using the
SecurityModule. This will call the handler for / redirect to the password form
and insure that the user can return to the same page (the original page will
be encoded in the caller_url parameter)


=head1 AUTHOR

Derek Feichtinger E<lt>derek.feichtinger@psi.chE<gt>

CMS web interfaces group E<lt>hn-cms-webInterfaces@cern.chE<gt>


=head1 ISSUES / TODO

List of issues to resolve:

=over 4

=item *

POST arguments are not carried across the password form

=item *

The mapping from username to certificate distinguished name needs to be established
separately.

=item *

Look at "TODO" comments in the code.

=back

=cut

