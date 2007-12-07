package PHEDEX::template::Agent;

=head1 NAME

PHEDEX::template::Agent - the template agent.

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Agent', 'PHEDEX::template::SQL';
use PHEDEX::Core::Logging;
use PHEDEX::Core::Timing;

our %params =
	(
	  MYNODE => undef,              # my TMDB nodename
    	  DBCONFIG => undef,		# Database configuration file
	  WAITTIME => 600 + rand(100)	# Agent cycle time
	);

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

# Pick up work from the database and start site specific scripts if necessary
sub idle
{
}

sub isInvalid
{
# This method is called after the object is initialised, but before it does
# any work. It's intended to validate the object structure/contents. You can
# use the parent PHEDEX::Core::Agent::IsInvalid method for routine checking
# of the existence and type-validity of members variables, and add your own
# specific checks here. Return non-zero for failure, and the agent will die.
#
# This happens before the agent becomes a daemon, so death will occur before
# leaving PID files in the system, etc.
  my $self = shift;
  my $errors = $self->SUPER::isInvalid
                (
                  REQUIRED => [ qw / MYNODE DROPDIR DBCONFIG / ],
                );
  return $errors;
}

1;
