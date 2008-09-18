package PHEDEX::CLI::Template;
#
# This is a template for the CLI function modules. The module name must be
# initial-caps followed by lowercase, i.e. no embedded caps. It must support
# the same functions as listed here.
#
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
  return 'Template';
}

sub ResponseIsValid
{
# This function checks that the response from the server is OK. Returns true
# if so, false otherwise.  Obviously this depends highly on what the
# object format is
  my ($self, $obj) = @_;
  my $payload  = $self->{PAYLOAD};
  # validate $obj here
  return 1;
}

# For debugging purposes only
sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub Report
{
# Print a human-readable output of the returned data object.
# Obviously this depends highly on what the object format is
  my ($self, $obj) = @_;
  # print $obj here
}

1;
