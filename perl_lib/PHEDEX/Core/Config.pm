package PHEDEX::Core::Config;

=head1 NAME

PHEDEX::Core::Config - Manage Agent configuration, manipulate Agents directly

=head1 SYNOPSIS

This module provides methods for reading PhEDEx configuration files and
executing commands within the corresponding agent environments, such as
starting agents, stopping them, and killing them. It also provides an
interface for access to the details of the configuration of an agent, such
as finding out where the state directory of a given agent is located.

=head1 DESCRIPTION

The PHEDEX::Core::Config object can read a PhEDEx config file and parse its
syntax. This syntax is not documented here, see the wiki probably (reference,
anyone?). As it parses the file it creates
L<PHEDEX::Core::Config::Agent|PHEDEX::Core::Config::Agent> and
L<PHEDEX::Core::Config::Environment|PHEDEX::Core::Config::Environment> objects
from the information.

After reading the file, the Agents or their Environments can be inspected, or
certain operations can be performed on the Agents. They can be started,
stopped, terminated, killed... The commands can be executed directly, or just
printed on STDOUT so you can inspect them.

Agents can be acted on in groups or individually, as appropriate.

Agents are stored in an array, in the order they are encountered in the config
file. This allows them to be operated on in that same order, in case it matters
for some reason. Environments are stored in a hash, as
C<< $config->{ENVIRONMENTS}{environment-name} >>, and can be simply retrieved
from there.

=head1 METHODS

=over

=item start( @agent_list )

Takes a list of agent names, or "all", or only the default agents if no
argument is given. Then it starts the agents with their correct
environment settings, as determined by the configuration file.

=item stop( @agent_list )

Takes a list of agent names, or "all", or only the default agents if no
argument is given. Then it stops the required agents cleanly, by placing a
"stop" file in their state directory.

=item show( @agent_list )

Takes a list of agent names, or "all", or only the default agents if no
argument is given. Then it shows the commands needed to set up the
environment and start the agents.

=item terminate( @agent_list )

Takes a list of agent names, or "all", or only the default agents if no
argument is given. Then it kills the agents with a TERM signal.

=item kill( @agent_list )

Takes a list of agent names, or "all", or only the default agents if no
argument is given. Then it kills the agents with a KILL signal.

=item select_agents( @agent_list )

Takes a list of agent names, or "all", or only the default agents if no
argument is given. Returns an array of
L<PHEDEX::Core::Config::Agent|PHEDEX::Core::Config::Agent> objects that
match the selection criteria.

If only one agent name is matched and the return-context is scalar, it
returns a reference to the object instead of an array.

If many agents are matched and the return-context is scalar, it returns a
reference to the array of agents that match.

=item dummy( $int )

Sets or returns the DUMMY flag in the Config object. If set to anything Perl
considers to be true, this tells the Config object to print to STDOUT instead
of actually executing the commands that follow. Useful if debugging.

There is a little redundancy here, in that C<< $config->show(); >> is
equivalent to C<< $config->dummy(1); $config->start(); >>

=item readConfig( $file )

Takes the name of a config file and reads it, parsing it on the way. Will die
if any errors are found.

This routine can be called several times, and existing environments are
appended to if new data is set for them. This is how IMPORT directives are
handled, for example.

=item getEnviron( $string )

Takes the name of an Environment and returns the
L<PHEDEX::Core::Config::Environment|PHEDEX::Core::Config::Environment> with
that name. Recursively finds the parent environments, see the
L<PHEDEX::Core::Config::Environment|PHEDEX::Core::Config::Environment>
documentation for details.

=item getAgentEnviron( $string )

Takes the name of an Agent, and returns its environment. i.e. the value of the
environment, not the environment object, and not the environment name.

=item command( $string, @agent_list )

Takes a command-string and an optional list of agent names, and executes the
command for those agents.

The command-string is checked against a hash to provide convenient shorthand
for commands like "kill", "terminate", etc, but in principle any properly
escaped string should work. This has not been tested!

The list of agent names can be "all" or empty, for all default agents.

=back

=head1 EXAMPLES

  my $config = PHEDEX::Core::Config->new();
  $config->readConfig($file);
  print $config->getEnviron("common"),"\n";
  print $config->getAgentEnviron("info-fs"),"\n";

  $config->dummy(1);
  $config->start("info-fs");
  $config->stop("info-fs");
  $config->kill();

=cut

use PHEDEX::Core::Config::Environment;
use PHEDEX::Core::Config::Agent;

our %params = (
		AGENTS       => undef,
		ENVIRONMENTS => undef,
		DUMMY	     => 0,
	      );

our %commands =
(
  terminate => "[ -f \$pidfile ] && kill \$(cat \$pidfile)",
  kill      => "[ -f \$pidfile ] && kill -9 \$(cat \$pidfile)",
  hup       => "[ -f \$pidfile ] && kill -HUP \$(cat \$pidfile)",
  stop      => "[ -d \$dropdir ] && touch \$dropdir/stop",
  start     => '#',
  show      => '#',
);

our $debug = 0;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  $self  = ref($proto) ? $class->SUPER::new(@_) : {};

  my %args = (@_);
  map {
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
      } keys %params;
  bless $self, $class;

  if ( ! exists($self->{ENVIRONMENTS}{common}) )
  {
    $self->{ENVIRONMENTS}{common} = PHEDEX::Core::Config::Environment->new
			(
				NAME	=> 'common',
				CONFIG	=> $self,
			 );
  }
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
  if ( exists($commands{$attr}) ) { return $self->command($attr,@_); }

  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

sub dummy
{
  my $self = shift;
  $self->{DUMMY} = shift if @_;
  return $self->{DUMMY};
}

sub readConfig
{
  my ($self,$file, $fhpattern) = @_;
  -f $file || die "$file: no such file\n";
  -r $file || die "$file: not readable\n";

# Record initial config-files (i.e. not recursively-opened files)
  my $depth = $fhpattern || 0;
  push @{$self->{CONFIG_FILES}}, $file unless $depth;

  $fhpattern++; # Avoid stomping over recursed files
  open($fhpattern, "< $file") || die "$file: cannot read: $!\n";
  while (<$fhpattern>)
  {
    while (defined $_ && /^\#\#\#\s+([A-Z]+)(\s+(.*)|$)/)
    {
      chomp; s/\s+$//;
      # Here we process ENVIRON sections, defined as follows:
      # ### ENVIRON [optional label]
      if ($1 eq "ENVIRON")
      {
        print STDERR "$file: $.: Unlabelled ENVIRONs are",
	    	     " deprecated, treating as 'common'\n"
	    if ! $3;

        my ($label,$env,$environment);
        $label = $3 || "common";

#       The environment may already exist, in which case append to it...
	$env = $self->{ENVIRONMENTS}{$label} ||
               PHEDEX::Core::Config::Environment->new
			(
				NAME	=> $label,
				CONFIG	=> $self,
			 );
        if ( $label ne 'common' && exists $self->{ENVIRONMENTS}{common} )
        {
          $env->PARENT('common');
        }
        $environment = $env->Environment();
        while (<$fhpattern>)
        {
	  last if /^###/; chomp; s/#.*//; s/^\s+//; s/\s+$//;
	  $environment .= "$_\n" if ($_ ne "");
        }
        $env->Environment($environment);
        $self->{ENVIRONMENTS}{$label} = $env;
      }

      # Here we process AGENT sections, defined as follows:
      # ### AGENT LABEL=<label> PROGRAM=<executable> [ENVIRON=<label>
      elsif ($1 eq "AGENT")
      {
        my %params = map { m|([^=]+)=(\S+)|g } split(/\s+/, $3);
        my $opts;
        while (<$fhpattern>)
        {
          last if /^###/; chomp; s/#.*//; s/^\s+//; s/\s+$//;
          next if m%^\s*$%;
          $opts .= " $_";
          next unless m%^\s*(\S+)\s+(.*)\s*$%;
          $params{OPTIONS}{$1} = $2;
        }
        my $agent = PHEDEX::Core::Config::Agent->new
		(
		  %params,
		  OPTS	=> $opts,
		);
        push @{$self->{AGENTS}}, $agent;
      }

      # Here we process IMPORT sections, defined as follows:
      # ### IMPORT FILE
      elsif ($1 eq "IMPORT")
      {
	my $dirpart = $file;
	my $newfile = $3;
	$dirpart =~ s|/[^/]+$||;
	$dirpart = "." if $dirpart eq $file;
	$self->readConfig ("$dirpart/$newfile", $fhpattern);
      }
      else
      {
	die "unrecognised section $1\n";
      }
    }
  }

  close ($fhpattern);

# Now add the config files to the common environment!
  if ( defined $self->{ENVIRONMENTS}{common} && !$depth )
  {
    my $e = $self->{ENVIRONMENTS}{common}->Environment();
    $e .= "export PHEDEX_CONFIG_FILE=" .
	   join(',',@{$self->{CONFIG_FILES}}) .
          "\n";
    $self->{ENVIRONMENTS}{common}->Environment($e);
  }
}

sub getEnviron
{
  my ($self,$label) = @_;

  return $self->{ENVIRONMENTS}{$label}->Environment()
	if exists $self->{ENVIRONMENTS}{$label};
  print STDERR "request for non-existent environment $label\n";
  return undef;
}

sub getAgentEnviron
{
  my ($self,$agent) = @_;
  my ($ename,$env);

  if ( ! ref($agent) )
  {
#   I have an agent name, instead of an agent object...
    $_ = $self->select_agents($agent);
    die "Couldn't identify agent '$agent'\n" if ref($_) eq 'ARRAY';
    $agent = $_;
  }
  $ename = $agent->ENVIRON;

  while ( $ename )
  {
    $env   = $self->{ENVIRONMENTS}{$ename}->Environment . $env;
    $ename = $self->{ENVIRONMENTS}{$ename}->PARENT;
  }
  return $env;
}

sub shell
{
  my $self = shift;

  return $self->{FH} = *STDOUT if $self->{DUMMY};

  open (SH, "| sh") or die "cannot exec sh: $!\n";
  return $self->{FH} = *SH;
}

sub start
{
  my $self = shift;
  $self->shell();
  $self->show(@_);
}

sub select_agents
{
  my $self = shift;
  my @a;
  undef @_ unless $_[0];

  foreach my $agent (@{$self->{AGENTS}})
  {
    next if (@_ && !grep($_ eq "all" || $_ eq $agent->LABEL, @_));
    next if (! @_ && ($agent->DEFAULT || 'on') eq 'off');
    push @a, $agent;
  }
  return $a[0] if ( scalar @a == 1 && ! wantarray );
  return \@a if ( ! wantarray );
  return @a;
}

sub show
{
  my $self = shift;
  my $FH = $self->{FH} || *STDOUT;

  foreach my $agent ( $self->select_agents(@_) )
  {
    my $dropdir  = $agent->DROPDIR;
    my $logdir   = $agent->LOGDIR;
    my $logfile  = $agent->LOGFILE;
    my $pidfile  = $agent->PIDFILE;

    print $FH "(\n", $self->getAgentEnviron($agent), "\n",
	 "export PHEDEX_AGENT_LABEL=",$agent->LABEL,"\n",
              "(mkdir -p $dropdir && mkdir -p $logdir";
    if ( $agent->STATELINK )
    {
warn "STATELINK can be better handled by getting the target state directory direct from the config file\n";
#      my $linked_agent = $self->select_agents($agent->STATELINK);
#      die "No linked agent found\n"
#	  unless $linked_agent && ! ref($linked_agent);
#      my $linked_env = $self->getAgentEnviron($linked_agent);
#      die "No linked environment\n" unless $linked_env;
#      print $FH " && ln -sf ",$agent->LABEL,"$linked_agent->DROPDIR;
      print $FH " && ln -sf ",$agent->LABEL,"\${PHEDEX_STATE}/",$agent->STATELINK;
    }
    print $FH 
         " && \${PHEDEX_SCRIPTS}/" . $agent->PROGRAM,
         (" -", $agent->STATEOPT || "state", " ", $dropdir),
         (" -log ", $logfile),
         $agent->{OPTS};

    print $FH "; renice ".$agent->NICE." -p \$(cat $pidfile)"
          if $agent->NICE;
    print $FH ")\n)\n";
  }

  close($FH);
}

sub command
{
  my $self = shift;
  my $cmd = shift;
  *FH = $self->shell();

  $cmd = $commands{$cmd} if defined $commands{$cmd};
  foreach my $agent ( $self->select_agents(@_) )
  {
    print FH "(",
	$self->getAgentEnviron($agent),
	"dropdir=", $agent->DROPDIR, ";\n",
	"logdir=",  $agent->LOGDIR, ";\n",
	"logfile=", $agent->LOGFILE, ";\n",
        $cmd, "\n)\n";
  }
  close(FH);
}

sub jobcount
{
  my $self = shift;
  my ($jobs,$agent);

  foreach $agent ( $self->select_agents(@_) )
  {
    $jobs += $agent->OPTIONS->{-jobs} || 0;
  }
  die "No agents selected\n" unless defined($jobs);
  return $jobs;
}

1;
