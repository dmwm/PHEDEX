use strict;
package T0::Logger::Monalisa;
use T0::Util;
use ApMon;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);

use Carp;
$VERSION = 1.00;
@ISA = qw/ Exporter /;
$Monalisa::Name = 'Logger::Monalisa';

our (@queue,%q);
our $hdr = __PACKAGE__ . ':: ';
sub Croak   { croak $hdr,@_; }
sub Carp    { carp  $hdr,@_; }
sub Verbose { T0::Util::Verbose( (shift)->{Verbose}, @_ ); }
sub Debug   { T0::Util::Debug(   (shift)->{Debug},   @_ ); }
sub Quiet   { T0::Util::Quiet(   (shift)->{Quiet},   @_ ); }

sub _init
{
  my $self = shift;

  $self->{Name} = $Monalisa::Name;
  $self->{Host} = 'lxarda12.cern.ch:18884';
  $self->{apmon}->{sys_monitoring} = 0;
  $self->{apmon}->{general_info}   = 0;

  my %h = @_;
  map { $self->{$_} = $h{$_}; } keys %h;
  $self->ReadConfig();

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
  T0::Util::ReadConfig($self);
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
    ${$_} = delete $h->{$_} or do
    {
      Carp "$_ not defined in call to ",__PACKAGE__,"\n";
      dump_ref($h);
      $$_ = 'T0::Unknown' . $_;
    };
  }
  print "$Cluster, $Node, ",%$h,"\n";
  $self->{apm}->sendParameters( $Cluster, $Node, %$h );
}

1;
