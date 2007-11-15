package PHEDEX::Core::Config::Agent;

=head1 NAME

PHEDEX::Core::Config::Agent - Manage Agent startup parameters

=head1 SYNOPSIS

This module is used by L<PHEDEX::Core::Config|PHEDEX::Core::Config> to manage
agent option definitions for anyone that needs them. There are no methods for
setting individual parameters, only for retrieving them.

=head1 DESCRIPTION

Agents in PhEDEx configuration files have a number of parameters that can
be set, such as their LABEL, the PROGRAM name, and so on. The
PHEDEX::Core::Config::Agent object allows you to set and retrieve these
values, though normally they are set only once in the constructor. There
are other methods to get the state directory and logfile (directory), these
being fixed derivatives of the other parameters and of the environment.

Agents exist in the context of an environment, managed by
L<PHEDEX::Core::Config::Environment|PHEDEX::Core::Config::Environment>.
The values of the agent parameters may use these environment variables
following the usual shell syntax. The Agents themselves only know the name of
their environment, they do not have a pointer to the Environment object that
contains the actual definition of the environment contents.

=head1 METHODS

=over

=item LABEL( $string )

The agent label, obligatory.

=item PROGRAM( $string )

Path to the program file for this agent, obligatory.

=item DEFAULT

"on" or "off" to denote agents that should or should not run by default.
Defaults to "on".

=item ENVIRON( $string )

The name of the environment that this agent needs. The "common" environment
is used by default.

=item OPTS( $string )

Command-line options for this agent, a single string.

=item OPTIONS

The same as OPTS, but expanded on the first whitespace into key => value pairs,
and stored in a hash. Use it to read individual parameters, you cannot set
them. This routine is not guaranteed to give correct results, check what it
gives you before using it! This is set by the parent
L<PHEDEX::Core::Config|PHEDEX::Core::Config> object and passed to the Agent
constructor.

In fact, best not to use it at all, just in case...

=item STATELINK( $string )

For relaying drops to other agents, the STATELINK parameter is used. How, I'm
not sure. It could be made obsolete, since an agent can now inspect the
configuration of the agent it relays to, and determine the dropbox directly,
instead of having to be told where it is.

=item STATEOPT( $string )

Some agents don't use "-state" to denote the state directory, they use another
option instead. The STATEOPT option holds the name of the state option in this
case.

=item NICE( $int )

If the agent is to be re-niced, the re-nice value is given here.

=item STATEDIR( $string )

Location of the agent state files/directories. This is a derived parameter,
and is not normally set in the configuration file.

=item LOGDIR( $string )

Directory where the agent logfile is written. This is a derived parameter,
and is not normally set in the configuration file.

=item LOGFILE( $string )

Full path to the agent logfile. This cannot be set, only read. If you want to
change the directory path for the logfile, set the LOGDIR, if you want to
change the actual filename, change the agent LABEL instead. This is a derived
parameter, and is not normally set in the configuration file.

=back

=head1 EXAMPLES

  my $agent = PHEDEX::Core::Config::Agent->new
    (
	LABEL   => "my-agent",
	ENVIRON => "common",
    );
  $agent->LOGDIR("/tmp");
  print "Logfile is at ",$agent->LOGFILE,"\n";
  print "The DB parameters argument is ",$agent->OPTIONS->{-db},"\n";

=cut

use File::Basename;
our %params = (
		LABEL     => undef,
		PROGRAM   => undef,
		DEFAULT   => 'on',
		ENVIRON   => 'common',
		OPTIONS   => undef,
		STATELINK => undef,
		STATEOPT  => undef,
		NICE      => undef,
		OPTS      => undef,
	      );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  my $self  = ref($proto) ? $class->SUPER::new(@_) : {};

  my %args = (@_);
  defined($args{LABEL}) or die "Unnamed Agents are not allowed\n";

  map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
      } keys %params;

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

sub STATEDIR
{
  my ($self,$dir) = @_;
  $self->{STATEDIR} = $dir ||
		      $self->{STATEDIR} ||
		      "\${PHEDEX_STATE}/" . $self->{LABEL};
  $self->{STATEDIR} .= '/' unless $self->{STATEDIR} =~ m%\/$%;
  return $self->{STATEDIR};
}

sub LOGDIR
{
  my ($self,$dir) = @_;
  $self->{LOGDIR} = $dir ||
		      $self->{LOGDIR} ||
		      "\${PHEDEX_LOGS}/";
  $self->{LOGDIR} .= '/' unless $self->{LOGDIR} =~ m%\/$%;
  return $self->{LOGDIR};
}

sub LOGFILE
{
  my ($self,$file) = @_;
  die "Cannot set LOGFILE, can only set LOGDIR\n" if $file;
  $self->{LOGFILE} = $self->LOGDIR . $self->{LABEL};
  return $self->{LOGFILE};
}

1;
