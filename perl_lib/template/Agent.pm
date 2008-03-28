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
use base 'PHEDEX::Core::POEAgent', 'template::SQL', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Timing;

our %params =
	(
	  MYNODE => undef,              # my TMDB nodename
    	  DBCONFIG => undef,		# Database configuration file
	  WAITTIME => 6 + rand(3),	# Agent cycle time
	  MYNEWPARAM => 'my value',
	  VERBOSE    => $ENV{PHEDEX_VERBOSE} || 0,
	  ME	     => 'template',
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

The methods provided here are all used in the base Agent class, and can be
overridden to specialise the agent. You can call the base class method in your
ovverride or, if you only need the base class behaviour, simply don't provide
the method in your agent.

These sample overrides just print their entry and exit, and call the base class
method o provide a minimal functioning agent.

=head2 init

The C<< init >> method is used to fully initialise the object. This is separate
from the constructor, and is called from the C<< process >> method. This gives
you a handle on things between construction and operation, so if we go to
running more than one agent in a single process, we can do things between the
two steps.

One thing in particular that the C<< init >> method can handle is string values
that need re-casting as arrays or hashes. We currently hard-code arrays such as
C<< IGNORE_NODES >> in our agents, but that can now be passed directly to the
agent in the constructor arguments as a string. The C<< init >> method in the
base class takes a key-value pair of 'ARRAYS'-(ref to array of strings). The
strings in the ref are taken as keys in the object, and, if the corresponding
key is set, it is turned into an array by splitting it on commas. If the key
is not set in the object, it is set to an empty array. This way,
C<< IGNORE_NODES >> and its cousins can be passed in from a configuration file
or from the command line. See C<< perl_lib/template/Agent.pl >> for an example
of how to do this, commented in the code.

=cut

sub init
{
  my $self = shift;

  print $self->Hdr,"entering init\n";
# base initialisation
  $self->SUPER::init(@_);

# Now my own specific values...
  $self->SUPER::init
	(
	  ARRAYS => [ @array_params ],
	  HASHES => [ @hash_params ],
	);
  print $self->Hdr,"exiting init\n";
}

=head2 idle

Pick up work from the database and start site specific scripts if necessary

=cut
sub idle
{
  my $self = shift;
  print $self->Hdr,"entering idle\n" if $self->{VERBOSE};
  $self->SUPER::idle(@_);
  print $self->Hdr,"exiting idle\n" if $self->{VERBOSE};
}

=head2 isInvalid

The isInvalid method is intended to validate the object structure/contents,
and is called from the PHEDEX::Core::Agent::process method. Return non-zero
for failure, and the agent will die.

You can use the parent PHEDEX::Core::Agent::IsInvalid method for routine
checking of the existence and type-validity of members variables, and add
your own specific checks here. The intent is that isInvalid should be
callable from anywhere in the code, should you wish to do such a thing, so
it should not have side-effects, such as changing the object contents or state
in any way. If you need to initialise an object further than you can in
C<< new >>, use the C<< init >> method to set it up.

You do not need to validate the basic PHEDEX::Core::Agent object, that will
already have happened in the constructor.

=cut
sub isInvalid
{
  my $self = shift;
  my $errors = 0;
  print $self->Hdr,"entering isInvalid\n" if $self->{VERBOSE};
  print $self->Hdr,"exiting isInvalid\n" if $self->{VERBOSE};

  return $errors;
}

=head2 stop

There's a C<< stop >> user hook, but I'm not sure who would need it...?

=cut
sub stop
{
  my $self = shift;
  print $self->Hdr,"entering stop\n" if $self->{VERBOSE};
  $self->SUPER::stop(@_);
  print $self->Hdr,"exiting stop\n" if $self->{VERBOSE};
}

=head2 processDrop

There's a C<< processDrop >> user hook too, but I'm not sure about that
either...

=cut
sub processDrop
{
  my $self = shift;
  print $self->Hdr,"entering processDrop\n" if $self->{VERBOSE};
  $self->SUPER::processDrop(@_);
  print $self->Hdr,"exiting processDrop\n" if $self->{VERBOSE};
}

1;
