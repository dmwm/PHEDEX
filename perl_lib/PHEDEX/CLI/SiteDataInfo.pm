package PHEDEX::CLI::SiteDataInfo;
use Getopt::Long;
use Data::Dumper;
use XML::Twig;
use strict;
use warnings;

our $asearchcli = 'https://cmsweb.cern.ch/dbs_discovery/aSearchCLI';
sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;

  my ($help,%params,%options);
  %params = (
	       LOCATION		=> 0,
	       ASEARCHCLI	=> $asearchcli,
	       NUMLIMIT		=> 0,
	       SITENAME		=> '%CSCS%',
	       STATS		=> 0,
	       XML		=> 0,
	       
	       VERBOSE	=> 0,
	       DEBUG	=> 0,
	    );
  %options = (
		'asearchcli|a=s'=> \$params{ASEARCHCLI},
		'location|l'	=> \$params{LOCATION},
		'numlimit|n=i'	=> \$params{NUMLIMIT},
		'sitename|s=s'	=> \$params{SITENAME},
		'stats|t'	=> \$params{STATS},
		'xml|x'		=> \$params{XML},

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

  Name: ListSiteDataInfo.pl - List requestor information on data sets stored at a site

  Synopsis: ListSiteDataInfo.pl  [options] --db file:instance -s site-name-pattern

  Description: This tool prints out information about all a site's local PhEDEx datasets
               useful for managing the local dataset pool.
               It prints out who made the request and the original comment, as well as
               dataset size. Optionally (using V. Kuznetsov's aSearchCLI tool) it also
               lists all replica locations of this dataset from DBS.

  options:
    -l/--location          :    print out location information (using V. Kuznetsov's aSearchCLI)
    -a/--asearchcli path   :    local path to aSearchCLI tool ($asearchcli)
                                Note that this takes some time
    -n/--numlimit          :    limit the number of datasets to be found
    -s/--sitename string   :    site's name query string, can contain '%'-wildcards
    -t/--stats             :    get stats on dataset size, blocks, and number of files
    -x/--xml               :    produce XML output

    -d/--debug             :    debug output
    -h/--help              :    help

  Examples:
      ListSiteDataInfo.pl --db DBParam.CSCS:Prod/CSCS -t -s '\%CSCS\%'
      # or for a small test with xml output (lists only 5 sets)
      ListSiteDataInfo.pl --db DBParam.CSCS:Prod/CSCS -s 'T1_DE_FZK_MSS' -t -x -n 5
      # small test including replica location information
      ListSiteDataInfo.pl --db DBParam.CSCS:Prod/CSCS -t -l -s '\%CSCS\%'
 
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
                  requestor => undef,
                  dataset   => undef,
                };
  foreach ( qw / LOCATION ASEARCHCLI NUMLIMIT SITENAME STATS XML / )
  { $payload->{$_} = $self->{$_}; }

  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = $payload;
}

sub Call
{
# This function returns a string, which is the name of the data-service
# function to call. Ideally, this should be the same as the name of this
# package, but may not always be. As here, using the 'bounce' call will
# simply return the parameters the user sent, which is fine for debugging
  return 'SiteDataInfo';
}

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
    $content = $content->{phedex}{SiteDataInfo} || {};
    foreach ( keys %{$self->{PAYLOAD}} )
    { $self->{RESPONSE}{$_} = $content->{$_}; }
  }
  print $self->Dump() if $self->{DEBUG};
}

sub ResponseIsValid
{
# This function checks that the response from the server is OK. Returns true
# if so, false otherwise. This example is not a rigorous validation, and
# assumes the response is in Perl Data::Dumper format!
  my $self = shift;
  my $payload  = $self->{PAYLOAD};
  my $response = $self->{RESPONSE};
  return 0 if $response->{ERROR};

  foreach ( keys %{$payload} )
  {
    if ( defined($payload->{$_}) && $payload->{$_} ne $response->{$_} )
    {
      print __PACKAGE__," wrong $_ returned\n";
      return 0;
    }
  }
  foreach ( qw / requestor dataset / )
  {
    next if defined($response->{$_});
    print __PACKAGE__," $_ not set in response\n";
    return 0;
  }
  print __PACKAGE__," response is valid\n" if $self->{VERBOSE};
  return 1;
}

# For debugging purposes only
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

  my $response = $self->{RESPONSE};
  my %dataset = %{$response->{dataset}};
  my %requestor = %{$response->{requestor}};
  my $dbg = $self->{DEBUG};

  print Dumper(\%requestor) if $dbg;
  print Dumper(\%dataset) if $dbg;

  if($self->{XML}) {
      my $twig = XML::Twig->new(pretty_print => 'indented');
      my $elt = create_element(datasetids => \%dataset);
      $twig->set_root($elt);
      $twig->print();
      exit(0);
  }

  foreach my $dsid (sort {$dataset{$a}{order} <=> $dataset{$b}{order}} keys %dataset) {
    print "*** Dataset: $dataset{$dsid}{name} ***\n";
    if($self->{STATS}) {
      printf("      %d GB  %d blocks, %d files\n", $dataset{$dsid}{bytes}/1024/1024/1024,$dataset{$dsid}{blocks},
	     $dataset{$dsid}{files});
    }
    foreach my $reqid ( sort {$a <=> $b} keys %{$dataset{$dsid}{requestids}}) {
      printf("   req.id:%d by %s at %s\n",$reqid,$dataset{$dsid}{requestids}{$reqid}{requestor},
	     scalar localtime($dataset{$dsid}{requestids}{$reqid}{time}));
      my $comment = $dataset{$dsid}{requestids}{$reqid}{comment} || '';
      printf("      comment: %s\n\n",$comment);
    }

    if ($self->{LOCATION}) {
      print "      Replicas: $dataset{$dsid}{replica_num}";
      my $counter=0;
      foreach my $loc ( split(/,/,$dataset{$dsid}{replica_loc}) ) {
        print "\n        Replicas at: " if($counter % 3 == 0);
        print "  $loc";
        $counter++;
      }
      print "\n";
    }

    print "----------------------------------------------------\n";
  }
}

# modified from perlmonks http://www.perlmonks.org/?node_id=439530
# used for constructing XML structure 
sub create_element
{
    my $gi   = shift;
    my $data = shift;
    my $attr = shift;

    my $t;
    if(defined $attr) {
        $t = XML::Twig::Elt->new($gi => $attr);
    } else {
        $t = XML::Twig::Elt->new($gi);
    }

    if (ref $data) {
        while (my ($k,$v) = each(%$data)) {
            my $newattr=undef;
            if($k =~ /^\d+$/) {
                $newattr={ id => $k};
                $k="${gi}_element";
            }
            create_element($k, $v, $newattr)->paste(last_child => $t);
        }
    }
    else {
        $t->set_text($data);
    }

    $t;
}

1;
