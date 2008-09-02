package PHEDEX::Transfer::Backend::Interface::GliteAsync;

=head1 NAME

PHEDEX::Transfer::Backend::Interface::GliteAsync - PHEDEX::Transfer::Backend::Interface::GliteAsync Perl module

=head1 SYNOPSIS

An interface to the glite- commands for the new PhEDEx transfer backend. Uses
POE::Component::Child to allow asynchronous use of the commands.

=head1 DESCRIPTION

pending...

=head1 METHODS

=cut

use strict;
use warnings;
use base 'PHEDEX::Transfer::Backend::Interface::Glite', 'PHEDEX::Core::Logging';
use POE;
use POE::Component::Child;

our %params =
	(
	  SERVICE	=> undef,	# Transfer service URL
	  MYPROXY	=> undef,
	  PASSWORD      => undef,
	  SPACETOKEN	=> undef,       
	  CHANNEL	=> undef,	# Channel name to match
	  USERDN	=> undef,	# Restrict to specific user DN
	  VONAME	=> undef,	# Restrict to specific VO
	  SSITE		=> undef,	# Specify source site name
	  DSITE		=> undef,	# Specify destination site name
	  ME		=> 'Glite',	# Arbitrary name for this object
	  PRIORITY	=> 3,		# Default piority configured in FTS channels
	  DEBUG		=> 0,
	  VERBOSE	=> 0,
	);

our %states =
	(
	  Submitted		=> 11,
	  Ready			=> 10,
	  Active		=>  9,
	  Finished		=>  0,
	  FinishedDirty		=>  0,
	  Pending		=> 10,
	  Default		=> 99,
	);

our %weights =
	(
	  Ready	  =>  1 + 0 * 300,
	  Active  =>  1 + 0 * 300,
	  Waiting =>  1 + 0 * 900,
	);

our %events = (
  stdout => \&_child_stdout,
  stderr => \&_child_stderr,
  error  => \&_child_error,
  done   => \&_child_done,
  died   => \&_child_died,
);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = ref($proto) ? $class->SUPER::new(@_) : {};

  my %args = (@_);
  map { 
        $self->{$_} = defined($args{$_}) ? $args{$_} : $params{$_}
      } keys %params;
  $self->{DEBUGGING} = $PHEDEX::Debug::Paranoid || 0;

  $self->{CHILD_EVENTS} = \%events;
  $self->{_child} = POE::Component::Child->new(
         events => \%events,
         debug => $self->{DEBUG} > 1 ? 1 : 0,
        );
  $self->{_child}{caller} = $self;

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

sub Parse
{
  my ($self,$wheel) = @_;
  my ($parse,$result);
  $parse = 'Parse' . $wheel->{parse};
  if ( $self->can($parse) ) { return $self->$parse($wheel); }
  return $result;
}

=head2 ParseListQueue

returns a hashref with information about all the jobs currently in the transfer
queue for the given FTS service (i.e. the one that the Glite object knows
about). The hash is keyed on the job-ids, the value being a subhash of ID,
STATE, and (FTS) SERVICE names.

In the event of an error the hash contains a single key, 'ERROR', with the
value being the text of the error message. Not very sophisticated but good
enough for now. Clients need only detect that the 'ERROR' key is present to
know something went wrong, or assume all is well if it isn''t there.

This function is not used by the backend in normal operation, but is useful in
passive monitoring mode.

=cut

sub ParseListQueue
{
  my ($self,$wheel) = @_;
  my ($result);
  $result = $wheel->{result};

  foreach ( @{$result->{RAW_OUTPUT}} )
  {
    m%^([0-9,a-f,-]+)\s+(\S+)$% or next;
    $result->{JOBS}{$1} = {ID => $1, STATE => $2, SERVICE => $self->{SERVICE}};
  }
  return $result;
}

sub ParseSubmit
{
  my ($self,$wheel) = @_;
  my ($job,$result);
  $result = $wheel->{result};
  $job    = $wheel->{arg};

  foreach ( @{$result->{RAW_OUTPUT}} )
  {
    m%^([0-9,a-f,-]+)$% or next;
    $job->ID( $1 );
  }
  return $result;
}

sub Run
{
  my ($self,$str,$postback,$arg) = @_;
  my $cmd   = $self->Command($str,$arg);

# Stub for now until I know how to sidestep unnecessary commands
  $cmd = '/bin/true' unless $cmd;

  my $logsafe_cmd = $cmd;
  $logsafe_cmd =~ s/ -p [\S]+/ -p _censored_/;
  $self->Logmsg("Run: $logsafe_cmd") if $self->{VERBOSE};
  my $wheel = $self->{_child}->run($cmd);

  $self->{wheels}{$wheel}{parse}    = $str;
  $self->{wheels}{$wheel}{postback} = $postback;
  $self->{wheels}{$wheel}{arg}      = $arg;
  $self->{wheels}{$wheel}{cmd}      = $str;
  $self->{wheels}{$wheel}{start}    = time;
  push @{$self->{wheels}{$wheel}{result}{INFO}}, $logsafe_cmd . "\n";
  return $wheel;
}

sub Command
{
  my ($self,$str,$arg) = @_;
  my $cmd;

  if ( $str eq 'ListQueue' )
  { return "glite-transfer-list -s " . $self->{SERVICE}; }

  if ( $str eq 'ListJob' )
  {
    $cmd = 'glite-transfer-status -l ';
    $cmd .= ' --verbose' if $arg->VERBOSE;
    $cmd .= ' -s ' . $arg->Service . ' ' . $arg->ID;
    return $cmd;
  }

  if ( $str eq 'SetPriority' )
  {

    my $priority = $arg->Priority;
    return undef unless $priority;
#   Save an interaction with the server ?
    return undef if $priority == $self->{PRIORITY};

    $cmd = 'glite-transfer-setpriority';
    if ( $arg->Service ) { $cmd .= ' -s ' . $arg->Service; }
    $cmd .= ' ' . $arg->ID . ' ' . $priority;
    return $cmd;
  }

  if ( $str eq 'Submit' )
  {
     $cmd = "glite-transfer-submit". 
      ' -s ' . $arg->Service .
      ((defined $self->MYPROXY)    ? ' -m '.$self->MYPROXY    : "") .
      ((defined $self->PASSWORD)   ? ' -p '.$self->PASSWORD   : "") .
      ((defined $self->SPACETOKEN) ? ' -t '.$self->SPACETOKEN : "") .
      ' -f ' . $arg->Copyjob;
      return $cmd;
  }

  return undef;
}

=head2 ParseListJob

Takes a single argument, a reference to a PHEDEX::Transfer::Backend::Job
object. Then issues glite-transfer-status for that job and picks through the
output. Returns a somewhat complex hashref with the result. As with ListQueue,
the hash will contain an 'ERROR' key if something went wrong, or not if the
command succeeded.

The keys returned in the hash are:

=over

RAW_OUTPUT is the unmolested text output of the status command, returned as a
reference to an array of lines. This is needed for debugging purposes.

The FILES key contains a subkey for each file in the job, keyed by destination
PFN. The function explicitly checks that it has keys for the DESTINATION,
DURATION, REASON, RETRIES, SOURCE and STATE of each file, or it dies, assuming
that something serious has gone wrong. This may not be correct behaviour. So,
the status of a particular destination PFN will be returned as C<<
$result->{FILES}{$destinationPFN}{STATE} >>.

The FILES_STATE key contains a hash of { STATE => state-count }, i.e. the
number of times a given file-state is encountered. Only states which are
actually encountered are present in the hash, so the existence of a given key
is not guaranteed.

The ETC key can be ignored for now. It should be set to zero. Eventually this
will be used as a means of estimating the time of completion of a given job,
which will affect its priority for monitoring.

=back

=cut

sub ParseListJob
{
  my ($self,$wheel) = @_;
  my ($result,$job);
  my ($cmd,$state,$dst,@raw);
  my ($key,$value);
  my (@h,$h,$preamble);

  $result = $wheel->{result};
  $job = $wheel->{arg};

  $result->{JOB_STATE} = 'undefined';
  return $result unless defined($result->{RAW_OUTPUT});

  $preamble=1;
  my $last_key;
  @raw = @{$result->{RAW_OUTPUT}};
  while ( $_ = shift @raw )
  {
    if ( $preamble )
    {
      if ( m%^\s*([A-Z,a-z]+)\s*$% ) # non-verbose case
      {
        $state = $1;
        $preamble = 0;
      }
      if ( m%^\s*Status:\s+([A-Z,a-z]+)\s*$% ) # verbose case
      {
        $state = $1;
      }
      if ( m%^\s+Source:\s+(.*)\s*$% )
      {
        unshift @raw, $_;
        $preamble = 0;
      }
      push @{$result->{INFO}}, $_ if $preamble;
      next;
    }

    if ( m%^\s+Source:\s+(.*)\s*$% )
    {
#     A 'Source' line is the first in a group for a single src->dst transfer
      push @h, $h if $h;
      undef $h;
    }
    if ( m%^\s+(\S+):\s+(.*)\s*$% )
    {
      $last_key = uc $1;
      $h->{$last_key} = $2;
    }
    elsif ( m%\S% )
    {
      $h->{$last_key} .= ' ' . $_;
    }
  }

  if ( defined($state) )
  {
    chomp $state;
    $result->{JOB_STATE} = $state;
  }

  push @h, $h if $h;
  foreach $h ( @h )
  {
#  Be paranoid about the fields I read!
    foreach ( qw / DESTINATION DURATION REASON RETRIES SOURCE STATE / )
    {
      die "No \"$_\" key! : ", map { "$_=$h->{$_} " } sort keys %{$h}
        unless defined($h->{$_});
    }
    $result->{FILES}{$h->{DESTINATION}} = $h;
  }

  my $time = time;
  foreach ( keys %{$result->{FILES}} )
  {
    $result->{FILE_STATES}{ $result->{FILES}{$_}{STATE} }++;
    $result->{FILES}{$_}{TIMESTAMP} = $time;
  }

  $result->{ETC} = 0;
# foreach ( keys %{$result->{FILE_STATES}} )
# {
#   $result->{ETC} += ( $weights{$_} || 0 ) * $result->{FILE_STATES}{$_};
# }

  return $result;
}

=head2 StatePriority

Takes a job state-name as argument, and returns an integer from a lookup
hash. Another half-formed idea, the intention was to use this in the
calculation of monitoring priorities too. This is not needed at the moment,
but this routine is still needed in the passive polling mode, which is used
in the standalone transfer prototype. Essentially the C<< %states >> hash
should have all known states listed in it as keys, with zero for the states
that correspond to job-exit, and any non-zero value for states which are not
terminal.

=cut

sub StatePriority
{
  my ($self,$state) = @_;
  return $states{$state} if defined($states{$state});
  return $states{Default} if !$self->{DEBUGGING};
  die "Unknown state \"$state\" encountered in ",__PACKAGE__,"\n";
}

=head2 SetPriority

Take a PHEDEX::Transfer::Backend::Job object reference as input, and, if
the job is specified to run at a different priority to the glite default,
set the priority accordingly in FTS.

=cut

sub SetPriority
{
  my ($self,$job) = @_;
  my ($priority,@raw,%result);
  return unless $priority = $job->Priority;
  return if $priority == $self->{PRIORITY}; # Save an interaction with the server

  my $cmd = "glite-transfer-setpriority";
  if ( $job->Service ) { $cmd .= ' -s ' . $job->Service; }
  $cmd .= ' ' . $job->ID . ' ' . $priority;
  print $self->Hdr,"Execute: $cmd\n";
  $result{CMD} = $cmd;
  open GLITE, "$cmd 2>&1 |" or die "$cmd: $!\n";
  while ( <GLITE> )
  {
    push @raw, $_;
  }
  close GLITE or do
  {
      print $self->Hdr,"close: $cmd: $!\n";
      push @{$result{ERROR}}, 'close SetPriority: id=' . $job->ID . ' ' . $!;
  };
  $result{RAW_OUTPUT} = \@raw;
  return \%result;
}

=head2 Submit

Take a PHEDEX::Transfer::Backend::Job object reference as input, submit the
job, and return a hashref with the resulting job ID. Returns a hashref keyed
on 'ERROR' if something goes wrong. The ID returned in the result is then used
when polling for the status of this job.

=cut

sub Submit
{
die "Shouldn't be here!\n";
  my ($self,$job) = @_;
  my (%result,@raw,$id);

  defined $job->COPYJOB or do
  {
    push @{$result{ERROR}}, 'Submit: No copyjob given for job ' . $job->ID;
    return \%result;
  };

  my $cmd = "glite-transfer-submit". 
      ' -s ' . $job->Service .
      ((defined $self->MYPROXY)    ? ' -m '.$self->MYPROXY    : "") .
      ((defined $self->PASSWORD)   ? ' -p '.$self->PASSWORD   : "") .
      ((defined $self->SPACETOKEN) ? ' -t '.$self->SPACETOKEN : "") .
      ' -f ' . $job->Copyjob;

  my $logsafe_cmd = $cmd;
  $logsafe_cmd =~ s/ -p [\S]+/ -p _censored_/;
  push @{$result{INFO}}, $logsafe_cmd . "\n";

  open GLITE, "$cmd 2>&1 |" or die "$logsafe_cmd: $!\n";
  while ( <GLITE> )
  {
    push @raw, $_;
    chomp;
    m%^([0-9,a-f,-]+)\s*$% or next;
    $id = $_ unless $id;
  }
  $result{RAW_OUTPUT} = \@raw;
  close GLITE or do
  {
      print $self->Hdr,"close: $logsafe_cmd: $!\n";
      push @{$result{ERROR}}, 'close Submit: JOBID=' . ( $id || 'undefined' ) . $!;
      return \%result;
  };
  print $self->Hdr,"JOBID=$id submitted...\n";
  $result{ID} = $id;
  $job->ID($id);

  $result{SETPRIORITY} = $self->SetPriority($job);

  return \%result;
}

# methods for the POE::Component::Child object
sub _child_stdout {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheel = $self->{caller}{wheels}{$args->{wheel}};
  push @{$wheel->{result}->{RAW_OUTPUT}}, $args->{out};
}

sub _child_stderr {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheel = $self->{caller}{wheels}{$args->{wheel}};
  chomp $args->{out};
  push @{$wheel->{result}->{ERROR}}, $args->{out};
}

sub _child_done {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheel = $self->{caller}{wheels}{$args->{wheel}};

# Some monitoring...
  my $duration = time - $wheel->{start};
  $self->{caller}->Logmsg("$wheel->{parse} cmd took $duration seconds") if $self->{caller}{VERBOSE};

  my $postback = $wheel->{postback};
  my $result = Parse( $self->{caller}, $wheel );
  $result->{DURATION} = $duration;
  if ( defined($wheel->{postback}) )
  {
    $wheel->{postback}->( $result, $wheel );
    return;
  }

  $result = $wheel->{result} unless defined($result);
  if ( $result && defined($wheel->{arg}) )
  {
    my ($job,$str,$k);
    $job = $wheel->{arg};
    $str = uc $wheel->{parse};
    foreach $k ( keys %{$result} )
    {
      if ( ref($result->{$k}) eq 'ARRAY' )
      {
        $job->Log(map { "$str: $k: $_" } @{$result->{$k}});
      }
      else
      {
        $job->Log("$str: $k: $result->{$k}");
      }
    }
  }

# cleanup...
  delete $self->{caller}{wheels}{$args->{wheel}};
}

sub _child_died {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheel = $self->{caller}{wheels}{$args->{wheel}};
  $args->{out} ||= '';
  chomp $args->{out};
  my $text = 'child_died: [' . $args->{rc} . '] ' . $args->{out};
  push @{$wheel->{result}->{ERROR}}, $text;
  _child_done( $self, $args );
}

sub _child_error {
  my ( $self, $args ) = @_[ 0 , 1 ];
  my $wheel = $self->{caller}{wheels}{$args->{wheel}};
  chomp $args->{error};
  my $text = 'child_error: [' . $args->{err} . '] ' . $args->{error};
  push @{$wheel->{result}->{ERROR}}, $text;
}

1;
