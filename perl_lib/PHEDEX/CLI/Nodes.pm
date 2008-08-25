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

sub ParseResponse
{
  my ($self,$response) = @_;
  no strict;

  my $content = $response->content();
  if ( $content =~ m%<error>(.*)</error>$%s ) { $self->{RESPONSE}{ERROR} = $1; }
  else
  {
    $content =~ s%^[^\$]*\$VAR1%\$VAR1%s;
    $content = eval($content);
    $content = $content->{phedex} || {};
    foreach ( keys %{$self->{PAYLOAD}} )
    { $self->{RESPONSE}{$_} = $content->{$_}; }
    foreach ( @{$content->{node}} )
    {
      $self->{RESPONSE}{Nodes}{delete $_->{NAME}} = $_;
    }
  }
  print $self->Dump() if $self->{DEBUG};
}

sub ResponseIsValid
{
  my $self = shift;
  my $payload  = $self->{PAYLOAD};
  my $response = $self->{RESPONSE};
  return 0 if $response->{ERROR};

  foreach ( keys %{$payload} )
  {
    if ( defined($payload->{$_}) && $payload->{$_} ne $response->{$_} )
    {
      print __PACKAGE__," wrong $_ returned\n";
      return 0;
    }
  }
  print __PACKAGE__," response is valid\n" if $self->{VERBOSE};
  return 1;
}

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]);
}

sub Summary
{
  my $self = shift;
  if ( $self->{RESPONSE}{ERROR} )
  {
    print __PACKAGE__ . "->Summary", $self->{RESPONSE}{ERROR};
    return;
  }
  return unless $self->{RESPONSE};

  my $first = 0;
  foreach my $n ( sort keys %{$self->{RESPONSE}{Nodes}} )
  {
    my $h = $self->{RESPONSE}{Nodes}{$n};
    $first++, print "NAME, ", join(', ', sort keys %{$h} ),"\n" unless $first;
    print $n,', ', join(', ', map {$h->{$_}||'(undef)'} sort keys %{$h}), "\n";
  }
}

1;
