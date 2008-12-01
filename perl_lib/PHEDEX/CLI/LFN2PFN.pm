package PHEDEX::CLI::LFN2PFN;
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
	       NODE	=> undef,
	       LFN	=> undef,
	       PROTOCOL	=> undef,
	       VERBOSE	=> 0,
	       DEBUG	=> 0,
	    );
  %options = (
	       'node=s@'	=> \$params{NODE},
	       'lfn=s@'		=> \$params{LFN},
	       'protocol=s'	=> \$params{PROTOCOL},
	       'destination=s'	=> \$params{DESTINATION},
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

 --node=s		(repeatable) required, node name
 --lfn=s		(repeatable) required, logical file name
 --protocol=s		required, transfer protocol
 --destination=s	destination node name

 ...and of course, it takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
  my $self = shift;
  my $payload = {
		  node		=> $self->{NODE},
		  lfn		=> $self->{LFN},
		  protocol	=> $self->{PROTOCOL},
		  destination   => $self->{DESTINATION} || ''
                };
  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = $payload;
}

sub Call { return 'LFN2PFN'; }

sub ResponseIsValid
{
  my ($self, $obj) = @_;
  my $payload  = $self->{PAYLOAD};

  my $mapping = $obj->{PHEDEX}{MAPPING};
  return 0 unless ref($mapping) eq 'ARRAY';

  print __PACKAGE__," response is valid\n" if $self->{VERBOSE};
  return 1;
}

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub Report
{
  my ($self, $obj) = @_;

  my $mapping = $obj->{PHEDEX}{MAPPING};

  foreach my $m (@$mapping) {
      print "$m->{LFN} $m->{PFN} $m->{SPACE_TOKEN}\n";
  }

}

1;
