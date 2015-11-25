package PHEDEX::Namespace::gfal::checksum;
# Implements the 'checksum' function for gfal access
use strict;
use warnings;

our @fields = qw / checksum_type checksum_value /;
sub new
{
  my ($proto,$h) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
	       cmd	=> 'gfal-sum',
	       opts	=> [],
	     };
  bless($self, $class);
  $self->{ENV} = $h->{ENV} || '';
  map { $self->{MAP}{$_}++ } @fields;
  return $self;
}

# Parse the checksum output.
sub parse {
	my ( $self, $ns, $r, $dir ) = @_;

	# gfal-sum returns only one line
	my $c = $r->{STDOUT}[0];

	# remove \n
	chomp($c);

	# return value is of the form "<file> <cksum>"
	$r->{checksum_value} = ( split( ' ', $c ) )[1];
	$r->{checksum_type} = 'adler32';

	return $r;
}

sub Help
{
  print 'Return (',join(',',@fields),")\n";
}

1;
