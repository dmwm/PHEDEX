package PHEDEX::CLI::Approve;
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
	      NODE	=> undef,
	      ACTION	=> undef,
	      RID	=> undef,
	    );
  %options = (
               'help'		=> \$help,
	       'verbose!'	=> \$params{VERBOSE},
	       'debug'		=> \$params{DEBUG},
	       'node=s@'	=> \$params{NODE},
 	       'action=s'	=> \$params{ACTION},
	       'rid=i'		=> \$params{RID},
 	       'comments=s'	=> \$params{COMMENTS}
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

 This command approves/disapproves a request, or simply adds a comment to it.

 Options:
 --action		'approve'    => Approve the request
			'disapprove' => Disapprove the request
			'nothing'    => no action (just add a comment)
 --rid			Request-ID to act on
 --node			Node to approve this request for. May be repeated
 --comments             comments on this request/subscription

 ...and of course, this module takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
  my $self = shift;
  my $payload;

  $payload->{action}   = $self->{ACTION};
  $payload->{rid}      = $self->{RID};
  $payload->{node}     = $self->{NODE};
  $payload->{comments} = $self->{COMMENTS};

  print __PACKAGE__," created payload\n" if $self->{VERBOSE};

  return $self->{PAYLOAD} = $payload;
}

sub Call { return 'approve'; }

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
