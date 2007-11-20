package PHEDEX::Core::Config::Environment;

=head1 NAME

PHEDEX::Core::Config::Environment - Manage Agent environment configuration parameters

=head1 SYNOPSIS

This module is used by L<PHEDEX::Core::Config|PHEDEX::Core::Config> to expand
environment variable definitions for anyone that needs them. There are no
methods for setting individual variables, only for inspecting them or for
setting the entire environment.

=head1 DESCRIPTION

PHEDEX::Core::Config::Environment objects are created and used by the
L<PHEDEX::Core::Config|PHEDEX::Core::Config> module. They allow an agent or
utility to inspect the environment used for a given agent, with the possibility
of fully expanding the definitions to final pathnames etc.

Environments can be hierarchical, the default being that all environments have
the "common" environment as a parent. So a parameter that is not defined in
a particular environment may be defined in its parent, and so on.

The environments themselves do not manage their parentage, it is up to the
L<PHEDEX::Core::Config|PHEDEX::Core::Config> object that creates them to set
the hierarchy by calling the PARENT method with the name of the parent
environment.

=head1 METHODS

=over

=item Environment( $string )

Set or return a string containing the full environment definition, with parents
at the head, but B<not> the environment of the actual script as well. I.e. it
only returns values that were read from the configuration file, but nothing that
already exists in the environment the process was executed in. This can be fed
straight to the shell to execute, to actually instantiate the environment.

=item getParameter( $string )

Takes a string parameter-name as input, and returns the value of that parameter
from the environment. If the parameter is not defined in the immediate
environment, it will be sought in the parent environments, until it is found.
If it is not found anywhere in the hierarchy of environments, it is sought in
the environment that the script is running in.

=item getExpandedParameter( $string )

Like C<getParameter>, but recursively expands variables used in the definition
of the parameter. So C<$PHEDEX_PATH/file.txt> would have the C<$PHEDEX_PATH>
expanded to its final value, etc. Recognises variables for expansion in the
formats C<$VAR> or C<${VAR}> only.

=item getExpandedString( $string )

Like C<getExpandedParameter>, but expands the input string directly, instead of
looking it up in the environment first. This allows you to evaluate arbitrary
expansions using the environment variables.

=item NAME( $string )

Name of the environment, obligatory, must be set in the constructor.

=item CONFIG( \$PHEDEX::Core::Config )

The Config object that creates this Environment object. This is
obligatory if you use hierarchies of environments, through the PARENT method.

=item PARENT( $string )

Set or get the name of the parent environment.

=back

=head1 EXAMPLES

  my $config = PHEDEX::Core::Config->new();
  $config->readConfig($file);
  my $env = $config->{ENVIRONMENTS}{common};
  print $env->getExpandedParameter('PHEDEX_MAP'),"\n";
  print $env->getExpandedParameter('PERL5LIB'),"\n";
  print $env->getExpandedParameter('WWW_HOME'),"\n";
  my $a = $config->select_agents('info-fs');
  print $env->getExpandedString($a->STATEDIR),"\n";
  print $env->getExpandedString($a->OPTIONS->{-db}),"\n";

=cut

our %params = (
		NAME	    => undef,
		PARENT      => undef,
		ENVIRONMENT => undef,
		CONFIG      => undef,
	      );

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  $self  = ref($proto) ? $class->SUPER::new(@_) : {};

  my %args = (@_);
  defined($args{NAME}) or die "Unnamed Environments are not allowed\n";

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

sub getParameter
{
  my ($self,$parameter) = @_;
  if ( ! defined($self->{KEYS}) )
  {
    foreach ( split("\n",$self->Environment || '') )
    {
      m%^([^=]*)=(.*)$%;
      $self->{KEYS}{$1} = $2;
    }
  }
  $_ = $self->{KEYS}{$parameter};
  if ( ! $_ && $self->{PARENT} )
  {
    $_=$self->{CONFIG}{ENVIRONMENTS}{$self->{PARENT}}->getParameter($parameter);
  }
  $_ = $ENV{$parameter} unless $_;
  s%;*$%% if $_;
  return $_ || '';
}

sub getExpandedString
{
  my ($self,$string) = @_;
  my $done = 0;
  while ( ! $done )
  {
    $done = 1;
    if ( $string =~ m%^([^{]*)\${([^}]*)}(.*$)% )
    {
      $string = $1 . $self->getParameter($2) . $3;
      $done = 0;
      next;
    }
    if ( $string =~ m%^([^{]*)\$([A-Z,0-9,_-]*)(.*$)% )
    {
      $string = $1 . $self->getParameter($2) . $3;
      $done = 0;
    }
  }
  return $string;
}

sub getExpandedParameter
{
  my ($self,$parameter) = @_;
  my $value = $self->getParameter($parameter);
  $value = $self->getExpandedString($value);
  return $value;
}

sub Environment
{
  my ($self,$environment) = @_;
  my $parent;
  if ( ! $environment )
  {
    my $parent;
    $parent = $self->{CONFIG}{ENVIRONMENTS}{$self->{PARENT}}->Environment if $self->{PARENT};
    return $self->{ENVIRONMENT};
  }
  undef $self->{KEYS};
  $self->{ENVIRONMENT} = $environment;
  return $self->Environment;

  $self->{ENVIRONMENT} = $environment;
}

1;
