package PHEDEX::CLI::DashboardStats;
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
	       SPAN	 => 86400,
	       FROM_NODE => '',
	       TO_NODE	 => '',
	       VERBOSE	 => 0,
	       DEBUG	 => 0,
	    );
  %options = (
	       'span=i'		=> \$params{SPAN},
	       'from=s'		=> \$params{FROM_NODE},
	       'to=s'		=> \$params{TO_NODE},
	       'help'		=> \$help,
	       'verbose!'	=> \$params{VERBOSE},
	       'debug'		=> \$params{DEBUG},
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

 simple debugging aid, returns the arguments you give it as a check that you can talk to
 your dataservice.

 ...and of course, this module takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
  my $self = shift;
  my %payload;
  foreach ( qw / FROM_NODE TO_NODE SPAN / )
  {
    $payload{$_} = $self->{$_};
  }
  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = \%payload;
}

sub Call { return 'DashboardStats'; }

sub ResponseIsValid
{
    my ($self, $obj)  = @_;
    my $payload  = $self->{PAYLOAD};

    # get the arg hash
    my $args = $obj->{PHEDEX}{DASHBOARDSTATS} || {};

    foreach ( keys %{$payload} )
    {
	if ( defined($payload->{$_}) && $payload->{$_} ne $args->{$_} )
	{
	    print __PACKAGE__," wrong $_ returned\n";
	    return 0;
	}
    }
    print __PACKAGE__," response is valid\n" if $self->{VERBOSE};
    return 1;
}

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub Report
{
    my ($self, $obj) = @_;

    # get the arg hash
    my $args = $obj->{PHEDEX}{DASHBOARDSTATS} || {};
    print "$_\t:\t$args->{$_}\n" foreach (keys %$args);
}

1;
