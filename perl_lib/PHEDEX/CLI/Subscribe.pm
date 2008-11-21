package PHEDEX::CLI::Subscribe;
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
	      DATAFILE	=> undef,
	      NODE	=> undef,
	      BLOCKLEVEL => 0,
	      PRIORITY  => 'low',
	      IS_STATIC => 0,
	      IS_MOVE   => 0,
	      IS_CUSTODIAL => 0,
	      USER_GROUP => undef,
	      REQUEST_ONLY => 0
	    );
  %options = (
               'help'		=> \$help,
	       'verbose!'	=> \$params{VERBOSE},
	       'debug'		=> \$params{DEBUG},
	       "datafile=s@"	=> \$params{DATAFILE},
	       "node=s@"	=> \$params{NODE},
 	       "block-level"    => \$params{BLOCKLEVEL},
	       "priority=s"     => \$params{PRIORITY},
	       "static"         => \$params{IS_STATIC},
	       "move"           => \$params{IS_MOVE},
 	       "custodial"      => \$params{IS_CUSTODIAL},
	       "group=s"        => \$params{USER_GROUP},
 	       "request-only"   => \$params{REQUEST_ONLY},
 	       "comments=s"     => \$params{COMMENTS}
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
 --datafile <filename>  name of an xml file. May be repeated, in which case the
			file contents are concatenated. The xml format is
			specified on the PhEDEx twiki on the 'Machine
			Controlled Subscriptions' project page
 --node <nodename>	name of the node this data is to be subscribed to. May
			be repeated to subscribe to multiple nodes.
 --block-level          subscribe to data at the block level.  The default is
                        to subscribe at the dataset level.
 --move                 make the subscription a move, default is a replica
 --priority <priority>  subscription priority, default is low
 --static               make the subscription static, default is a growing
                        subscription
 --custodial            make the subscription custodial, default is non-custodial
 --group                make this subscription for the specified group, default is
                        undefined
 --request-only         make a request for transfer only, do not approve
 --comments             comments on this request/subscription

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

  $payload->{node}      = $self->{NODE};
  $payload->{priority}  = $self->{PRIORITY};
  $payload->{level}     = $self->{BLOCKLEVEL} ? 'block' : 'dataset';
  $payload->{move}      = $self->{IS_MOVE} ? 'y' : 'n';
  $payload->{static}    = $self->{IS_STATIC} ? 'y' : 'n';
  $payload->{custodial} = $self->{IS_CUSTODIAL} ? 'y' : 'n';
  $payload->{group}     = $self->{USER_GROUP};
  $payload->{request_only} = $self->{REQUEST_ONLY} ? 'y' : 'n';
  $payload->{comments}  = $self->{COMMENTS};

  foreach ( @{$self->{DATAFILE}} )
  {
    open DATA, "<$_" or die "open: $_ $!\n";
    $payload->{data} .= join('',<DATA>);
    close DATA;
  }

  print __PACKAGE__," created payload\n" if $self->{VERBOSE};

  return $self->{PAYLOAD} = $payload;
}

sub Call { return 'Subscribe'; }

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
