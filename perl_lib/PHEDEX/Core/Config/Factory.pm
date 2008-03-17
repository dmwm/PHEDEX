package PHEDEX::Core::Config::Factory;

=head1 NAME

PHEDEX::Core::Config::Factory - a module for creating agents

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent> 

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::POEAgent', 'PHEDEX::Core::Logging';
use POE;
use PHEDEX::Core::Timing;

our %params =
	(
	  MYNODE	=> undef,		# my TMDB nodename
	  WAITTIME	=> 6 + rand(3),		# This agent cycle time
	  VERBOSE	=> $ENV{PHEDEX_VERBOSE},
	  AGENTS	=> undef,		# Which agents am I to start?
	  CONFIG	=> $ENV{PHEDEX_CONFIG_FILE},
	  NODAEMON	=> 1,			# Don't daemonise by default!
	  STATISTICS_INTERVAL	=> 3600,	# reporting frequency
	  STATISTICS_DETAIL	=>    1,	# reporting level: 0, 1, or 2
	);

our @array_params = qw / AGENT_NAMES /;
our @hash_params  = qw / /;

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

sub createAgents
{
  my $self = shift;

  my ($Config,$Agent,%Agents,%Modules,$agent);

  $Config = PHEDEX::Core::Config->new( PARANOID => 1 );
  $Config->readConfig( $self->{CONFIG} );
  $self->{CONFIGURATION} = $Config;

  foreach $agent ( @{$self->{AGENTS}} )
  {
    $self->Logmsg("Lookup agent \"$agent\"");
    $Agent = $Config->select_agents( $agent );

#   Paranoia!
    if ( $agent ne $Agent->LABEL )
    {
      die "given \"$agent\", but found \"",$Agent->LABEL,"\"\n";
    }

    my $module = $Agent->PROGRAM;
    $self->Logmsg("$agent is in $module");
    if ( !exists($Modules{$module}) )
    {
      $self->Logmsg("Attempt to load $module");
      eval("use $module");
      do { chomp ($@); die "Failed to load module $module: $@\n" } if $@;
      $Modules{$module}++;
    }
    my %a = @_;
    $a{ME} = $agent;
    $a{NODAEMON} = 1;
    my $opts = $Agent->OPTIONS;
    $opts->{DROPDIR} = '${PHEDEX_STATE}/' . $agent;
    $opts->{LOGFILE} = '${PHEDEX_LOGS}/'  . $agent;

    my $env = $Config->{ENVIRONMENTS}{$Agent->ENVIRON};
    foreach ( keys %{$opts} )
    {
      $a{$_} = $env->getExpandedString($opts->{$_}) unless exists($a{$_});
    }

    $Agents{$agent} = eval("new $module(%a)");
    do { chomp ($@); die "Failed to create agent $module: $@\n" } if $@;
  }
  return ($self->{AGENTS} = \%Agents);
}

sub really_daemon
{
# I need these gymnastics because the Factory must not become a daemon until
# it has started all the agents, then it should do it's stuff. I should clean
# this up if I can.
  my $self = shift;
  $self->{NODAEMON}=0;
  $self->SUPER::daemon( $self->{ME} );
  $self->Logmsg('I have successfully become a daemon');
  $self->Logmsg('I am running these agents: ',join(', ',sort keys %{$self->{AGENTS}}));
}

sub idle
{
  my $self = shift;
  $self->Logmsg("entering idle") if $self->{VERBOSE};
  $self->SUPER::idle(@_);
  $self->Logmsg("exiting idle") if $self->{VERBOSE};
}

sub isInvalid
{
  my $self = shift;
  my $errors = 0;
  $self->Logmsg("entering isInvalid") if $self->{VERBOSE};
  $self->Logmsg("exiting isInvalid") if $self->{VERBOSE};

  return $errors;
}

sub stop
{
  my $self = shift;
  $self->Logmsg("entering stop") if $self->{VERBOSE};
  $self->SUPER::stop(@_);
  $self->Logmsg("exiting stop") if $self->{VERBOSE};
}

sub _poe_init
{
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];
  $kernel->state('_make_stats', $self);
  $kernel->yield('_make_stats');
}

sub _make_stats
{
  my ($self,$kernel,$session) = @_[ OBJECT, KERNEL, SESSION ];

  if ( ! defined($self->{stats}{START}) )
  {
    $self->Logmsg('STATISTICS: Reporting every ',$self->{STATISTICS_INTERVAL},' seconds, detail=',$self->{STATISTICS_DETAIL});
    $self->{stats}{START} = time;
    $kernel->delay_set('_make_stats',$self->{STATISTICS_INTERVAL});
    return;
  }

  my ($totalWall,$totalCPU);
  $totalCPU = 0;
  foreach my $agent ( sort keys %{$self->{AGENTS}} )
  {
    next unless $self->{AGENTS}{$agent}{internalStats};
    my $h = $self->{AGENTS}{$agent}{internalStats};
    my $maybeStop = $h->{maybeStop};
    next unless $maybeStop;
    my $summary = "STATISTICS: $agent maybeStop=$maybeStop";
    my $onCPU=0;
    if ( $h->{process} )
    {
      my $count = $h->{process}{count} || 0;
      my @a = sort { $a <=> $b } @{$h->{process}{time}};
      foreach ( @a ) { $onCPU += $_; }
      $totalCPU += $onCPU;
      my $max = $a[-1];
      my $median = $a[int($count/2)];
      $summary .= sprintf(" process=%d total_wall=%.2f median=%.2f max=%.2f",$count,$onCPU,$median,$max);
      if ( $self->{STATISTICS_DETAIL} > 1 )
      {
        $summary .= ' full_timing=(' . join(',',map { $_=int(1000*$_)/1000 } @a) . ')';
      }
    }
    delete $self->{AGENTS}{$agent}{internalStats};
    $self->Logmsg($summary) if $self->{STATISTICS_DETAIL};
  }

  $totalWall = time - $self->{stats}{START};
  my $busy= 100*$totalCPU/$totalWall;
  my $summary=sprintf('TotalCPU=%.2f busy=%.2f%%',$totalCPU,$busy);
  $self->Logmsg($summary);
  $self->{stats}{START} = time;
  $kernel->delay_set('_make_stats',$self->{STATISTICS_INTERVAL});
}

1;
