package PHEDEX::CLI::Delete;
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
	      VERBOSE	 => 0,
	      DEBUG	 => 0,
	      DATAFILE	 => undef,
	      NODE	 => undef,
	      BLOCKLEVEL => 0,
	      MAIL	 => 1
	    );
  %options = (
               'help'		=> \$help,
	       'verbose!'	=> \$params{VERBOSE},
	       'debug'		=> \$params{DEBUG},
	       "datafile=s@"	=> \$params{DATAFILE},
	       "node=s@"	=> \$params{NODE},
 	       "block-level"    => \$params{BLOCKLEVEL},
	       "mail!"          => \$params{MAIL},
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
and uses the dataservice to delete the data from one or more PhEDEx nodes.

 Options:
 --datafile <filename>  name of an xml file. May be repeated, in which case the
			file contents are concatenated. The xml format is
			specified on the PhEDEx twiki on the 'Machine
			Controlled Subscriptions' project page
 --node <nodename>	name of the node this data is to be deleted from. May
			be repeated to delete from multiple nodes.
 --block-level          delete data at the block level.  The default is
                        to delete at the dataset level.
 --no-mail              do not send request email to requestor, datamanagers,
                        site admins, and global admins; default is to send email
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

  $payload->{level}     = $self->{BLOCKLEVEL} ? 'block' : 'dataset';
  $payload->{node}      = $self->{NODE};
  $payload->{no_mail}   = $self->{MAIL} ? 'n' : 'y';
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

sub Call { return 'Delete'; }

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

1;
