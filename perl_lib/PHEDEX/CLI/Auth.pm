package PHEDEX::CLI::Auth;
use Getopt::Long;
use Data::Dumper;
use strict;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my ($help,%params,%options);
  %params = (
	      VERBOSE	=> 0,
	      DEBUG	=> 0,
	      NODES	=> undef,
	    );
  %options = (
               'help'		=> \$help,
	       'verbose!'	=> \$params{VERBOSE},
	       'debug!'		=> \$params{DEBUG},
	       'node=s@'	=> \$params{NODES},
	     );
  GetOptions(%options);
  my $self = \%params;
  print "I am in ",__PACKAGE__,"->new()\n" if $self->{VERBOSE};

  bless $self, $class;
  $self->Help() if $help;
  return $self;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($self->{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
}

sub Help
{
  print "\n Usage for ",__PACKAGE__,"\n";
  die <<EOF;

 This module checks that you are authorised to use the PhEDEx dataservice.
By default, it checks that you have a PhEDEx role and that there are at least
some nodes you are allowed to operate on. If you use the "--nodes <s>" option,
you can explicitly check that a given node is in the list, the module will
terminate with an error otherwise. "--node" can be repeated, to check for a
set of nodes.

 ...and of course, this module takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
  my $self = shift;
  my $payload = { };
  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = $payload;
}

sub Call { return 'checkAuth'; }

sub ParseResponse
{
# assume the response is in Perl Data::Dumper format!
  my ($self,$response) = @_;

  no strict;
  my $content = eval($response->content());
  $content = $content->{phedex}{auth} || {};
  foreach ( qw / STATE DN NODES / )
  { $self->{RESPONSE}{$_} = $content->{$_}; }
  @{$self->{RESPONSE}{ROLES}} = ();
  foreach my $role ( keys %{$content->{ROLES}} )
  {
    foreach ( @{$content->{ROLES}{$role}} ) 
    { push @{$self->{RESPONSE}{ROLES}},$role if m%^phedex$%; }
  }
  print $self->Dump() if $self->{DEBUG};
}

sub ResponseIsValid
{
  my $self = shift;
  my $response = $self->{RESPONSE};

# Check that the user certificate was accepted, that they have valid roles
# for PhEDEx, and that they have a set of nodes they can act on
  die "Certificate not accepted\n"    unless $response->{STATE} eq 'cert';
  die "You have no valid roles\n"     unless scalar @{$response->{ROLES}};
  die "You have no nodes to act on\n" unless scalar keys %{$response->{NODES}};

# Check the list of nodes for validity
  if ( $self->{NODES} )
  {
    foreach ( @{$self->{NODES}} )
    {
      die "Required node \"$_\" not found in authorised list\n" unless
	$response->{NODES}{$_};
    }
  }
  print __PACKAGE__," response is valid\n" if $self->{VERBOSE};
  return 1;
}

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
