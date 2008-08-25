package PHEDEX::CLI::BlockReplicas;
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
	       NODE	   => undef,
	       BLOCK	   => undef,
	       SE	   => undef,
	       UPDATE_SINCE => undef,
	       CREATE_SINCE => undef,
	       COMPLETE	   => undef,
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

  --node=s		(repeatable) node name
  --block=s		(repeatable) block name
  --se=s		(repeatable) storage element name
  --update_since	unix epoch time for last update to blocks
  --create_since	unix epoch time for creation of blocks
  --complete		(negatable) block-completion flag

 ...and of course, this module takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
  my $self = shift;
  my $payload = { };
  foreach ( qw / NODE BLOCK SE UPDATE_SINCE CREATE_SINCE COMPLETE / )
  { $payload->{$_} = $self->{$_}; }

  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = $payload;
}

sub Call { return 'BlockReplicas'; }

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
    $content = $content->{phedex}{BlockReplicas} || 
               $content->{phedex} ||
               {};
    $self->{RESPONSE} = $content;
  }
  print $self->Dump() if $self->{DEBUG};
}

sub ResponseIsValid
{
  my $self = shift;
  my $payload  = $self->{PAYLOAD};
  my $response = $self->{RESPONSE};
  return 0 if $response->{ERROR};
  return 0 unless defined( @{$response->{block}} );

  print __PACKAGE__," response is valid\n" if $self->{VERBOSE};
  return 1;
}

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub Summary
{
  my $self = shift;
  if ( $self->{RESPONSE}{ERROR} )
  {
    print __PACKAGE__ . "->Summary", $self->{RESPONSE}{ERROR};
    return;
  }
  return unless $self->{RESPONSE};
  print Data::Dumper->Dump([ $self->{RESPONSE} ],[ __PACKAGE__ . '->Summary' ]);
}

1;
