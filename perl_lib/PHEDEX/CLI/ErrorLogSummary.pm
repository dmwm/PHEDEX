package PHEDEX::CLI::ErrorLogSummary;
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
            FROM => undef,
            TO => undef,
            BLOCK => undef,
            DATASET => undef,
            LFN => undef,
            VERBOSE => 0,
            DEBUG => 0,
          );
  %options = (
            'from=s@' => \$params{FROM},
            'to=s@' => \$params{TO},
            'block=s' => \$params{BLOCK},
            'dataset=s' => \$params{DATASET},
            'lfn=s' => \$params{LFN},
            'help' => \$help,
            'verbose' => \$params{VERBOSE},
            'debug' => \$params{DEBUG},
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

  List blocks and files with logged errors. Options are:

  --from=s      (repeatable) source node name
  --to=s        (repeatable) destination node name
  --block=s     block name
  --dataset=s   dataset name
  --lfn=s       logical file name

 ...and of course, this module takes the standard options:
 --help, --(no)debug, --(no)verbose

EOF
}

sub Payload
{
  my $self = shift;
  my $payload = {
                    from => undef,
                    to => undef,
                    block => undef,
                    dataset => undef,
                    lfn => undef,
                };
  foreach ( qw / FROM TO BLOCK DATASET LFN / )
  { $payload->{$_} = $self->{$_}; }

  print __PACKAGE__," created payload\n" if $self->{VERBOSE};
  return $self->{PAYLOAD} = $payload;
}

sub Call { return 'ErrorLogSummary'; }

sub ResponseIsValid
{
  my ($self, $obj) = @_;
  my $payload  = $self->{PAYLOAD};

  my $links = $obj->{PHEDEX}{LINK};
  if (ref $links ne 'ARRAY' || !@$links) {
    return 0;
  }

  print __PACKAGE__," response is valid\n" if $self->{VERBOSE};
  return 1;
}

sub Dump { return Data::Dumper->Dump([ (shift) ],[ __PACKAGE__ ]); }

sub Report
{
  my ($self, $obj) = @_;

  my $fmt = "%-15s | %-15s | %s\n";
  printf $fmt, "# FROM", "TO", "NAME";

  my $links =  $obj->{PHEDEX}{LINK};
  foreach my $l ( @$links )
  {
    my $blocks = $l->{BLOCK};
    foreach my $b ( @$blocks )
    {
      my $files = $b->{FILE};
      foreach my $f ( @$files )
      {
        printf $fmt, $l->{FROM}, $l->{TO}, $f->{NAME};
      }
    }
  }
}

1;
