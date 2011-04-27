package PHEDEX::CLI::Subscriptions;
use warnings;
use strict;
use Getopt::Long;

=pod

=head1 NAME

PHEDEX::CLI::Subscriptions -- show which subscriptions exist and their parameters.

=head1 DESCRIPTION

Show existing subscriptions and their parameters.

=head2 Options

  dataset          dataset name (wildcards)
  block            block name (wildcards)
  node             node name (wildcards)
  se               storage element
  create_since     timestamp. only subscriptions created after.*
  request          request number which created the subscription.
  custodial        y or n to filter custodial/non subscriptions.
                   default is null (either)
  group            group name filter 
  priority         priority, one of "low", "normal" and "high"
  move             y (move) or n (replica)
  suspended        y or n, default is either

  * when no arguments are specified, default create_since is set to 1 day ago

=cut

our %params = (
               NODE     	=> undef,
               VERBOSE		=> 0,
               DEBUG		=> 0,
	       DATASET		=> undef,
	       BLOCK		=> undef,
	       SE		=> undef,
	       CREATE_SINCE	=> undef,
	       REQUEST		=> undef,
	       CUSTODIAL	=> undef,
	       GROUP		=> undef,
	       PRIORITY		=> undef,
	       MOVE		=> undef,
	       SUSPENDED	=> undef,
              );
sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my ($help,%options);
  %options = (
               'help'           => \$help,
               'verbose!'       => \$params{VERBOSE},
               'debug'          => \$params{DEBUG},
               'node=s'         => \$params{NODE},
	       'dataset=s'	=> \$params{DATASET},
	       'block=s'	=> \$params{BLOCK},
	       'se=s'		=> \$params{SE},
	       'create_since'	=> \$params{CREATE_SINCE},
	       'request=i'	=> \$params{REQUEST},
	       'custodial=s'	=> \$params{CUSTODIAL},
	       'group=s'	=> \$params{GROUP},
	       'priority=s'	=> \$params{PRIORITY},
	       'move=s'		=> \$params{MOVE},
	       'suspended=s'	=> \$params{SUSPENDED},
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

 return the TFC from somewhere...

 ...and of course, this module takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
  my $self = shift;
  my $payload;
  map { $payload->{$_} = $self->{$_} } keys %params;
  map { delete $payload->{$_} } ( qw / VERBOSE DEBUG HELP / );
  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = $payload;
}

sub Call { return 'Subscriptions'; }

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
