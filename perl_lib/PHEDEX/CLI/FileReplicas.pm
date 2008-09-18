package PHEDEX::CLI::FileReplicas;
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
	       NODE		=> undef,
	       BLOCK		=> undef,
	       SE		=> undef,
	       UPDATE_SINCE	=> undef,
	       CREATE_SINCE	=> undef,
	       COMPLETE		=> undef,
	       DIST_COMPLETE	=> undef,

	       VERBOSE	=> 0,
	       DEBUG	=> 0,
	    );
  %options = (
	       'node=s@'	=> \$params{NODE},
	       'block=s@'	=> \$params{BLOCK},
	       'se=s@'		=> \$params{SE},
	       'update_since=i'	=> \$params{UPDATE_SINCE},
	       'create_since=i'	=> \$params{CREATE_SINCE},
	       'complete!'	=> \$params{COMPLETE},
	       'dist_complete!'	=> \$params{DIST_COMPLETE},
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

 return the list of file replicas for a given block. Takes the following arguments:
  --node=s              (repeatable) node name
  --block=s             (repeatable) block name
  --se=s                (repeatable) storage element name
  --update_since        unix epoch time for last update to blocks
  --create_since        unix epoch time for creation of blocks
  --complete            (negatable) block-completion flag
  --dist_complete       (negatable) block-distribution completion flag

 ...and of course, it takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
  my $self = shift;
  my $payload = {
		  block => $self->{BLOCK},
                };
  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = $payload;
}

sub Call { return 'FileReplicas'; }

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
