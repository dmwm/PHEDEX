package PHEDEX::CLI::Subscribe;
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
	      DATAFILE	=> undef,
	      NODE	=> undef,
	    );
  %options = (
               'help'		=> \$help,
	       'verbose!'	=> \$params{VERBOSE},
	       'debug!'		=> \$params{DEBUG},
	       "datafile=s@"	=> \$params{DATAFILE},
	       "node=s@"	=> \$params{NODE},
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

 This command accepts one or more XML datafiles for uploading to a dataservice,
and uses the dataservice to subscribe them to one or more PhEDEx nodes.

 Options:
 --datafile <filename>	name of an xml file. May be repeated, in which case the
			file contents are concatenated. The xml format is
			specified on the PhEDEx twiki on the 'Machine
			Controlled Subscriptions' project page
 --node <nodename>	name of the node this data is to be subscribed to. May
			be repeated to subscribe to multiple nodes.

 ...and of course, this module takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
  my $self = shift;
  my $payload;

  die __PACKAGE__," no datafiles given\n" unless $self->{DATAFILE};
  die __PACKAGE__," no node given\n" unless $self->{NODE};

  $payload->{node} = $self->{NODE};
  foreach ( @{$self->{DATAFILE}} )
  {
    open DATA, "<$_" or die "open: $_ $!\n";
    $payload->{data} .= join('',<DATA>);
    close DATA;
  }

  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = $payload;
}

sub Call { return 'subscribe'; }

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
# assume the response is in Perl Data::Dumper format!
  my $self = shift;
  my $payload  = $self->{PAYLOAD};
  my $response = $self->{RESPONSE};
  return 0 if $response->{ERROR};

  if ( $payload->{data} ne $response->{data} )
  {
    print __PACKAGE__," wrong data returned\n" if $self->{VERBOSE};
    return 0;
  }

  my %h;
  foreach ( @{$payload->{node}} ) { $h{$_}++; }
  foreach ( @{$response->{node}} ) { delete $h{$_}; }
  if ( $_ = join(', ',sort keys %h) )
  {
    print __PACKAGE__," missing nodes: $_\n" if $self->{VERBOSE};
    return 0;
  }
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
# print Data::Dumper->Dump([ $self->{RESPONSE} ],[ __PACKAGE__ . '->Summary' ]);
}

1;
