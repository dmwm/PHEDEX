package PHEDEX::CLI::Nodes;
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
	    );
  %options = (
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

 Return a hashref of the nodes known to PhEDEx. The hashref key is the node
name, and the value is a sub hashref with keys for ID, Kind, SE-name, and
Technology.

 There are no meaningful arguments to this module...
 ...but of course, this module takes the standard options:
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

sub Call { return 'Nodes'; }

sub ResponseIsValid
{
  my ($self, $obj) = @_;
  my $payload  = $self->{PAYLOAD};

  my $nodes = $obj->{PHEDEX}{NODE};
  if (ref $nodes ne 'ARRAY' || !@$nodes) {
      return 0;
  }

  print __PACKAGE__," response is valid\n" if $self->{VERBOSE};
  return 1;
}

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub Report
{
  my ($self, $obj) = @_;

  my $nodes = $obj->{PHEDEX}{NODE};

  my @head = qw( NAME SE KIND TECHNOLOGY );

  my $first = 0;
  foreach my $n ( sort { $a->{NAME} cmp $b->{NAME} } @$nodes)
  {
    $first++, print join(', ', @head),"\n" unless $first;
    print join(', ', map {$n->{$_}||'(undef)'} @head), "\n";
  }
}

1;
