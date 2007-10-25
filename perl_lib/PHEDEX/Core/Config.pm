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

...pending

=head1 METHODS

...pending

=EXAMPLES

...pending

=cut

our %params = (
		CONFIG   => undef,
		MODE     => undef,
		AGENTS   => undef,
		ENVIRONS => undef,
		DUMMY	 => 0,
	      );

our %commands =
(
  terminate => "[ -f \$statedir/pid ] && kill \$(cat \$statedir/pid)",
  kill      => "[ -f \$statedir/pid ] && kill -9 \$(cat \$statedir/pid)",
  stop      => "[ -d \$statedir ] && touch \$statedir/stop",
  dummy     => 'echo "dummy command..."',
  printenv  => 'printenv | sort',
);

our $debug = 0;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  $self = $class->SUPER::new(@_) if ref($proto);
  my %args = (@_);
  map { $self->{$_} = $args{$_} || $params{$_} } keys %params;
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
  if ( exists($commands{$attr}) ) { return $self->Command($attr,@_); }

  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

sub Dummy
{
  my $self = shift;
  $self->{DUMMY} = shift if @_;
  return $self->{DUMMY};
}
sub readConfig
{
  my ($self,$file, $fhpattern) = @_;
  $fh = 'fh00' unless $fh;
  -f $file || die "$file: no such file\n";
  -r $file || die "$file: not readable\n";

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

        my $label = $3 || "common";
        while (<$fhpattern>)
        {
	  last if /^###/; chomp; s/#.*//; s/^\s+//; s/\s+$//;
	  $self->{ENVIRONS}{$label} .= "$_\n" if ($_ ne "");
        }
      }

      # Here we process AGENT sections, defined as follows:
      # ### AGENT LABEL=<label> PROGRAM=<executable> [ENVIRON=<label>
      elsif ($1 eq "AGENT")
      {
        my $agent = { map { m|([^=]+)=(\S+)|g } split(/\s+/, $3) };
        push(@{$self->{AGENTS}}, $agent);
        while (<$fhpattern>)
        {
          last if /^###/; chomp; s/#.*//; s/^\s+//; s/\s+$//;
          $agent->{OPTS} .= " $_" if ($_ ne "");
        }
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
}

sub getEnviron
{
  my ($self,$environ) = @_;

  return $self->{ENVIRONS}{$environ} if exists $self->{ENVIRONS}{$environ};
  print STDERR "request for non-existent environment $environ\n";
  return undef;
}

sub getAgentEnviron
{
  my ($self,$agent) = @_;

  return undef unless $agent->{ENVIRON};

  return $self->{ENVIRONS}{$agent->{ENVIRON}}
	if exists $self->{ENVIRONS}{$agent->{ENVIRON}};

  print STDERR "Agent $agent->{LABEL} requests non-existent",
	" environment $agent->{ENVIRON}\n";
  return;
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

  foreach my $agent (@{$self->{AGENTS}})
  {
    next if (@_ && !grep($_ eq "all" || $_ eq $agent->{LABEL}, @_));
    next if (! @_ && ($agent->{DEFAULT} || 'on') eq 'off');
    push @a, $agent;
  }
  return @a;
}

sub show
{
  my $self = shift;
  my $FH = $self->{FH} || *STDOUT;

  foreach my $agent ( $self->select_agents(@_) )
  {
    print $FH "(",
	$self->getEnviron('common'),
	$self->getAgentEnviron($agent), "\n";

    # Now actually act on the mode, and start or show agents
    my $logdir = "\${PHEDEX_LOGS}";
    my $logfile = "$logdir/$agent->{LABEL}";
    my $statedir = "\${PHEDEX_STATE}/$agent->{LABEL}";

    print $FH
        ("mkdir -p $statedir &&",
         " mkdir -p $logdir &&",
         ($agent->{STATELINK}
          ? " ln -sf $agent->{LABEL} \${PHEDEX_STATE}/$agent->{STATELINK}; " : " :;"),
         " \${PHEDEX_SCRIPTS}/$agent->{PROGRAM}",
         (" -", $agent->{STATEOPT} || "state", " ", $statedir),
         (" -log ", $logfile),
         $agent->{OPTS});

    print $FH "; renice $agent->{NICE} -p \$(cat $statedir/pid)"
          if $agent->{NICE};
    print $FH ")\n";
  }

  close($FH);
}

sub Command
{
  my $self = shift;
  my $cmd = shift;
  *FH = $self->shell();

  foreach my $agent ( $self->select_agents(@_) )
  {
    my $statedir = "\${PHEDEX_STATE}/$agent->{LABEL}";
    print FH "(",
	$self->getEnviron('common'),
	$self->getAgentEnviron($agent),
	"statedir=$statedir;\n",
        $commands{$cmd}, "\n)\n";
  }
  close(FH);
}

sub environ
{
  my $self = shift;
  foreach my $label (@_ ? @_ : "common")
  {
    print $self->{ENVIRONS}{$label}, "\n";
  }
}

1;
