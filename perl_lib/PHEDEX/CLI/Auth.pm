package PHEDEX::CLI::Auth;
use Getopt::Long;
use Data::Dumper;
use strict;
use warnings;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my ($help,%params,%options);
  %params = (
	      VERBOSE	=> 0,
	      DEBUG	=> 0,
	      NODES	=> undef,
	      REQUIRE_CERT => 0,
	      ABILITY => undef
	    );
  %options = (
               'help'		=> \$help,
	       'verbose!'	=> \$params{VERBOSE},
	       'debug'		=> \$params{DEBUG},
	       'node=s@'	=> \$params{NODES},
	       'require_cert'	=> \$params{REQUIRE_CERT},
	       'ability'	=> \$params{ABILITY},
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

 This module checks that your authorization with the PhEDEx Data
 Service.  Returns a list of roles that you have from SiteDB.  If
 '-ability <s>' is provided, returns a list of nodes for which you
 have that ability.  If -requre_cert is provided, returns an error if
 you are not authenticated by certificate.

 ...and of course, this module takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
  my $self = shift;
  my $payload = { require_cert => $self->{REQUIRE_CERT} ,
		  ability => $self->{ABILITY}
	      };
  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = $payload;
}

sub Call { return 'Auth'; }

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }


1;
