package PHEDEX::CLI::Template;
#
# This is a template for the CLI function modules. The module name must be
# initial-caps followed by lowercase, i.e. no embedded caps. It must support
# the same functions as listed here.
#
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
	    );
  %options = (
	       'help'		=> \$help,
	       'verbose!'	=> \$params{VERBOSE},
	       'debug!'		=> \$params{DEBUG},
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

 Help description goes here...

 ...and of course, this module takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
# This function returns a hashref, the contents of which can be POSTed to
# the server. This forms the body of the request to the data-service
  my $self = shift;
  my $payload = {
                  this_is => 'something to send to the server',
                  it_should => 'be a hashref!'
                };
  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = $payload;
}

sub Call
{
# This function returns a string, which is the name of the data-service
# function to call. Ideally, this should be the same as the name of this
# package, but may not always be. As here, using the 'bounce' call will
# simply return the parameters the user sent, which is fine for debugging
  return 'bounce';
}

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
  }
  print $self->Dump() if $self->{DEBUG};
}

sub ResponseIsValid
{
# This function checks that the response from the server is OK. Returns true
# if so, false otherwise. This example is not a rigorous validation, and
# assumes the response is in Perl Data::Dumper format!
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

sub Dump
{
# For debugging purposes only
  return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]);
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
# print Data::Dumper->Dump([ $self->{RESPONSE} ],[ __PACKAGE__ . '->Summary' ]);
}

1;
