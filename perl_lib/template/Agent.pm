package template::Agent;

=head1 NAME

template::Agent - the template agent.

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'template::SQL';
use PHEDEX::Core::Logging;
use PHEDEX::Core::Timing;

our %params =
	(
	  MYNODE => undef,              # my TMDB nodename
    	  DBCONFIG => undef,		# Database configuration file
	  WAITTIME => 6 + rand(3),	# Agent cycle time
	  MYNEWPARAM => 'my value',
	);

our @array_params = qw / MYARRAY /;
our @hash_params  = qw / MYHASH /;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(%params,@_);
  bless $self, $class;
  return $self;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;
  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }
  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

=head1 Overriding base-class methods

=head2 init

The C<< init >> method is used to fully initialise the object. This is separate
from the constructor 

=cut
sub init
{
  my $self = shift;

  print scalar localtime," $self->{ME}: entering init\n";
# base initialisation
  $self->SUPER::init(@_);

# Now my own specific values...
  $self->SUPER::init
	(
	  ARRAYS => [ @array_params ],
	  HASHES => [ @hash_params ],
	);
  print scalar localtime," $self->{ME}: exiting init\n";
}

# Pick up work from the database and start site specific scripts if necessary
sub idle
{
  my $self = shift;
  print scalar localtime," $self->{ME}: entering idle\n";
  $self->SUPER::idle(@_);
  print scalar localtime," $self->{ME}: exiting idle\n";
}

=head2 isInvalid

The isInvalid method is intended to validate the object structure/contents,
and is called from the PHEDEX::Core::Agent::process method. Return non-zero
for failure, and the agent will die.

You can use the parent PHEDEX::Core::Agent::IsInvalid method for routine
checking of the existence and type-validity of members variables, and add
your own specific checks here.

You do not need to validate the basic PHEDEX::Core::Agent object, that will
already have happened in the constructor.

=cut
sub isInvalid
{
  my $self = shift;
  my $errors = 0;
  print scalar localtime," $self->{ME}: entering isInvalid\n";
  print scalar localtime," $self->{ME}: exiting isInvalid\n";

  return $errors;
}

=head2 stop

There's a C<< stop >> user hook, but I'm not sure who would need it...?

=cut
sub stop
{
  my $self = shift;
  print scalar localtime," $self->{ME}: entering stop\n";
  $self->SUPER::stop(@_);
  print scalar localtime," $self->{ME}: exiting stop\n";
}

=head2 processDrop

There's a C<< processDrop >> user hook too, but I'm not sure about that
either...

=cut
sub processDrop
{
  my $self = shift;
  print scalar localtime," $self->{ME}: entering processDrop\n";
  $self->SUPER::processDrop(@_);
  print scalar localtime," $self->{ME}: exiting processDrop\n";
}

1;
