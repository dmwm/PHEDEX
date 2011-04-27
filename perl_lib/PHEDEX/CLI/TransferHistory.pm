package PHEDEX::CLI::TransferHistory;
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
	       TO	   => undef,
	       FROM	   => undef,
	       STARTTIME   => undef,
	       ENDTIME     => undef,
	       BINWIDTH    => undef,
	       VERBOSE	=> 0,
	       DEBUG	=> 0,
	    );
  %options = (
	       'to=s'		=> \$params{TO},
	       'from=s'		=> \$params{FROM},
	       'starttime=i'	=> \$params{STARTTIME},
	       'endtime=i'	=> \$params{ENDTIME},
	       'binwidth=i'	=> \$params{BINWIDTH},
	       'help'		=> \$help,
	       'verbose!'	=> \$params{VERBOSE},
	       'debug'		=> \$params{DEBUG},
	     );
  GetOptions(%options);
  my $self = \%params;

  if ( defined($self->{COMPLETE}) )
  {
    $self->{COMPLETE} = $self->{COMPLETE} ? 'y' : 'n';
  }

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

 List block replicas. Options are:

  --to=s		destination node name
  --from=s		source node name
  --starttime		unix epoch time for last update to blocks
  --endtime		unix epoch time for creation of blocks
  --binwidth		(negatable) block-completion flag

 ...and of course, this module takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
  my $self = shift;
  my $payload = { };
  foreach ( qw / STARTTIME ENDTIME BINWIDTH TO FROM / )
  { $payload->{$_} = $self->{$_}; }

  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = $payload;
}

sub Call { return 'TransferHistory'; }

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
