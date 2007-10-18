use strict;
package PHEDEX::Monalisa;
use ApMon;

=head1 NAME

PHEDEX::Monalisa - facilitate reporting to Monalisa

=head1 DESCRIPTION

Requires a host or host:port to which to send its information, then simply
call the C<$self->Send()> method to send values to a Monalisa server at that
location.

The Send function takes one argument, a hashref, which has two obligatory
keys with string values:

=over

=item *

C<Cluster> is the name of the cluster, in Monalisa parlance, that the data
belongs to.

=item *

C<Node> the node name, again in Monalisa terms.

=head1 EXAMPLE

Using the Tier0 Monalisa server, for example:

  my $apmon = PHEDEX::Monalisa->new (
                Cluster => 'PhEDEx',
                apmon   =>
                {
                  sys_monitoring => 1,
                  general_info   => 1,
                },
                Host    => '
                @ARGV,
        );

=cut

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);

use Carp;
$VERSION = 1.00;
@ISA = qw/ Exporter /;
$Monalisa::Name = 'PHEDEX::Monalisa';

our (@queue,%q);
our $hdr = __PACKAGE__ . ':: ';
sub Croak   { croak $hdr,@_; }
sub Carp    { carp  $hdr,@_; }

sub _init
{
  my $self = shift;

  $self->{Name} = $Monalisa::Name;
  $self->{Host} = 'lxarda12.cern.ch:18884';
  $self->{apmon}->{sys_monitoring} = 0;
  $self->{apmon}->{general_info}   = 0;

  my %h = @_;
  map { $self->{$_} = $h{$_}; } keys %h;
# $self->ReadConfig();

  $self->{apm} = new ApMon( { $self->{Host} => $self->{apmon} } );

  return $self;
}

sub new
{
  my $proto  = shift;
  my $class  = ref($proto) || $proto;
  my $parent = ref($proto) && $proto;
  my $self = {  };
  bless($self, $class);
  $self->_init(@_);
}

sub Options
{
  my $self = shift;
  my %h = @_;
  map { $self->{$_} = $h{$_}; } keys %h;
}

our @attrs = ( qw/ Host Port Name / );
our %ok_field;
for my $attr ( @attrs ) { $ok_field{$attr}++; }

sub AUTOLOAD {
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  Croak "AUTOLOAD: Invalid attribute method: ->$attr()" unless $ok_field{$attr};
  $self->{$attr} = shift if @_;
  return $self->{$attr};
}

sub ReadConfig
{
  my $self = shift;
  my $file = $self->{Config};
# T0::Util::ReadConfig($self);
}

sub Send
{
  my $self = shift;
  my $h;
  
  if ( scalar(@_) == 1 ) { $h = shift; }
  else
  {
    my %h = @_;
    $h = \%h;
  }

  delete $h->{MonaLisa} if defined $h->{MonaLisa};

  no strict 'refs';
  our ( $Cluster, $Node );
  foreach ( qw / Cluster Node / )
  {
    ${$_} = $h->{$_} or do
    {
      Carp "$_ not defined in call to ",__PACKAGE__,"\n";
    };
  }
  if ( $self->{verbose} )
  {
     print map { " $_=$h->{$_}" } sort keys %{$h}; print "\n";
  }
  $self->{apm}->sendParameters( $Cluster, $Node, %$h );
}

1;
