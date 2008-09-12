package PHEDEX::Monitoring::Process;
use strict;
use warnings;
use PHEDEX::Core::Timing;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};
  my %params = (
	  	  ME		=> 'MonitoringProcess',
		  PAGESIZE	=> undef,
		  PID		=>'self',
		 );
  my %args = (@_);
  map { $self->{$_} = $args{$_} || $params{$_} } keys %params;
  $self->{states} = {};
  $self->{stats}  = {};
  bless $self, $class;
  return $self;
}

sub PageSize
{
  my $self = shift;
  return $self->{PAGESIZE} if $self->{PAGESIZE};
  open CONF, "getconf PAGESIZE|" or die "getconf PAGESIZE: $!\n";
  my $pagesize = <CONF>;
  close CONF;
  chomp $pagesize;
  $pagesize or die "Cannot determine memory pagesize!\n";
  return $self->{PAGESIZE} = $pagesize;
}

sub ProcessStats
{
  my ($self,$pid) = @_;
  $pid = $self->{PID} unless $pid;
  return $self->{stats}{$pid};
}

sub ReadProcessStats
{
  my ($self,$pid) = @_;
  my (@a,$pagesize,%h);

  $pid = $self->{PID} unless $pid;
  $pagesize = $self->PageSize();

  open PROC, "</proc/$pid/statm" or do { warn "/proc/$pid: $!\n"; return; };
  $_ = <PROC>;
  close PROC or die "Error closing /proc/$pid/statm: $!\n";
  @a = split(' ',$_);
  $h{VSize} = $a[0] * $pagesize / 1024 / 1024; # in MB
  $h{RSS}   = $a[1] * $pagesize / 1024 / 1024;

  open PROC, "</proc/$pid/stat" or do { warn "/proc/$pid: $!\n"; next; };
  $_ = <PROC>;
  close PROC or die "Error closing /proc/$pid/stat: $!\n";
  my @b = split(' ',$_);
  $h{Utime} = $b[13] / 100; # normalise to seconds
  $h{Stime} = $b[14] / 100;

  my $h = $self->{stats}{$pid};
  $self->{stats}{$pid} = \%h;
  foreach ( keys %h )
  {
    my $x = 0;
    $x = $h{$_} - $h->{$_} if $h->{$_};
    $self->{stats}{$pid}{'d' . $_} = $x;
  }
}

sub FormatStats
{
  my ($self,$pid) = @_;
  my ($h,$l);

  $pid = $self->{PID} unless $pid;
  $h = $self->{stats}{$pid} or return '$pid=undef';

  foreach ( qw / RSS VSize Stime Utime dRSS dVSize dStime dUtime / )
  {
    $l  .= sprintf("%s=%.3f ",$_,$h->{$_});
  }
  chomp $l;
  return $l;
}

sub ResetState
{
  my ($self,$state) = @_;
  undef $self->{states}{$state};
  $self->{states}{$state}{cumulative} = 0;
}

sub Calls
{
  my ($self,$state) = @_;
  return $self->{states}{$state}{calls};
}

sub State
{
  my ($self,$state,$key) = @_;
  $self->{states}{$state}{$key} = mytimeofday() if $key;

  if ( $key eq 'start' ) { $self->{states}{$state}{calls}++; }
  if ( $key eq 'call'  ) { $self->{states}{$state}{calls}++; }

  if ( $key eq 'stop' )
  {
    $self->{states}{$state}{cumulative} +=
	$self->{states}{$state}{stop} - $self->{states}{$state}{start};
  }
  return $self->{states}{$state};
};

sub FormatStates
{
  my ($self,$detail) = @_;
  my ($h,$l);

  $h = $self->{states} or return 'state=undef';

  foreach ( sort keys %{$h} )
  {
    my $t = ($h->{$_}{stop} || time) - $h->{$_}{start};
    if ( $detail )
    {
      $l .= sprintf("cycle_time(%s=%.6f,cumulative=%.3f,calls=%d) ",$_,$t,
			$h->{$_}{cumulative},$h->{$_}{calls});
    }
    else
    {
      $l .= sprintf("cycle_time(%s=%.3f) ",$_,$t);
    }
  }
  chomp $l;
  return $l;
}

1;
