package PHEDEX::Transfer::Backend::Interface::Glite;

=head1 NAME

PHEDEX::Transfer::Backend::Interface::Glite - PHEDEX::Transfer::Backend::Interface::Glite Perl module

=head1 SYNOPSIS

An interface to the glite- commands for the new PhEDEx transfer backend.

=head1 DESCRIPTION

pending...

=head1 METHODS

=cut

use strict;
use warnings;
use base 'PHEDEX::Core::Logging';

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

=head2 ListQueue

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

sub ListQueue
{
  my $self = shift;
  my ($cmd,$job,$state,%result,@raw);

  $cmd = "glite-transfer-list -s " . $self->{SERVICE};
  open GLITE, "$cmd 2>&1 |" or do
  {
      print "$cmd: $!\n";
      $result{ERROR} = 'ListQueue: ' . $self->{SERVICE} . ': ' . $!;
      return \%result;
  };
  while ( <GLITE> )
  {
    push @raw, $_;
    m%^([0-9,a-f,-]+)\s+(\S+)$% or next;
    $result{$1} = { ID => $1, STATE => $2, SERVICE => $self->{SERVICE} };
  }
  close GLITE or do
  {
      print "close: $cmd: $!\n";
      $result{ERROR} = 'close ListQueue: ' . $self->{SERVICE} . ': ' . $!;
  };
  $result{RAW_OUTPUT} = \@raw;
  return \%result;
}

=head2 ListJob

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

sub ListJob
{
  my ($self,$job) = @_;
  my ($cmd,$state,%result,$dst,@raw);
  my ($key,$value);
  my (@h,$h,$preamble);

  $cmd = 'glite-transfer-status -l ';
# $cmd .= ' --verbose' if $job->VERBOSE;
  $cmd .= ' -s ' . $job->Service . ' ' . $job->ID;
  open GLITE, "$cmd 2>&1 |" or do
  {
      print "$cmd: $!\n";
      $result{ERROR} = 'ListJob: ' . $job->ID . ': ' . $!;
      return \%result;
  };
  @raw = <GLITE>;
  $result{RAW_OUTPUT} = [@raw];
  close GLITE or do
  {
      print "close: $cmd: $!\n";
      $result{ERROR} = 'close ListJob: ' . $job->ID . ':' . $!;
      return \%result;
  };

  $preamble=1;
  while ( $_ = shift @raw )
  {
    print "raw: $_";
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
        $preamble = 0;
      }
      if ( m%^\s+Source:\s+(.*)\s*$% )
      {
        unshift @raw, $_;
        $preamble = 0;
      }
      next;
    }

    if ( m%^\s+Source:\s+(.*)\s*$% )
    {
#     A 'Source' line is the first in a group for a single src->dst transfer
      push @h, $h if $h;
      undef $h;
    }
    if ( m%^\s+(\S+):\s+(.*)\s*$% ) { $h->{uc $1} = $2; }
  }

  chomp $state if (defined $state);
  $result{JOB_STATE} = $state || 'undefined';

  push @h, $h if $h;
  foreach $h ( @h )
  {
#  Be paranoid about the fields I read!
    foreach ( qw / DESTINATION DURATION REASON RETRIES SOURCE STATE / )
    {
      die "No \"$_\" key! : ", map { "$_=$h->{$_} " } sort keys %{$h}
        unless defined($h->{$_});
    }
    $result{FILES}{$h->{DESTINATION}} = $h;
  }

  my $time = time;
  foreach ( keys %{$result{FILES}} )
  {
    $result{FILE_STATES}{ $result{FILES}{$_}{STATE} }++;
    $result{FILES}{$_}{TIMESTAMP} = $time;
  }

  $result{ETC} = 0;
# foreach ( keys %{$result{FILE_STATES}} )
# {
#   $result{ETC} += ( $weights{$_} || 0 ) * $result{FILE_STATES}{$_};
# }

  return \%result;
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
#$DB::single=1;
  return unless $priority = $job->Priority;
  return if $priority == $self->{PRIORITY}; # Save an interaction with the server

  my $cmd = "glite-transfer-setpriority";
  if ( $job->Service ) { $cmd .= ' -s ' . $job->Service; }
  $cmd .= ' ' . $job->ID . ' ' . $priority;
  print $self->Hdr,"Execute: $cmd\n";
  open GLITE, "$cmd 2>&1 |" or die "$cmd: $!\n";
  while ( <GLITE> )
  {
    push @raw, $_;
  }
  close GLITE or do
  {
      print "close: $cmd: $!\n";
      $result{ERROR} = 'close SetPriority: id=' . $job->ID . ' ' . $!;
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
  my ($self,$job) = @_;
  my (%result,@raw,$id);

  defined $job->COPYJOB or do
  {
    $result{ERROR} = 'Submit: No copyjob given for job ' . $job->ID;
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
  push @raw, $logsafe_cmd . "\n";

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
      print "close: $logsafe_cmd: $!\n";
      $result{ERROR} = 'close Submit: id=' . ( $id || 'undefined' ) . $!;
      return \%result;
  };
  print $self->Hdr,"Job $id submitted...\n";
  $result{ID} = $id;
  $job->ID($id);

  $result{INFO} = $self->SetPriority($job);

  return \%result;
}

1;
