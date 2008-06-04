package PHEDEX::Transfer::Backend::Interface::SRM;

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
use MIME::Base64 ();

our %params =
	(
	  SERVICE	=> undef,	# Transfer service URL
	  MYPROXY	=> undef,	# Transfer service URL
	  CHANNEL	=> undef,	# Channel name to match
	  USERDN	=> undef,	# Restrict to specific user DN
	  VONAME	=> undef,	# Restrict to specific VO
	  SSITE		=> undef,	# Specify source site name
	  DSITE		=> undef,	# Specify destination site name
	  ME		=> 'SRM',	# Arbitrary name for this object
	);

# These states are defined and explained here:
# http://t2.unl.edu/documentation/dcache/nebraska-srm-clients/
our %states =
	(
	  SRM_SUCCESS                   =>  0,
	  SRM_REQUEST_QUEUED            =>  1,
	  SRM_REQUEST_INPROGRESS        =>  2,
	  SRM_PARTIAL_SUCCESS           =>  3,
	  SRM_AUTHENTICATION_FAILURE    =>  4,
	  SRM_AUTHORIZATION_FAILURE     =>  5,
	  SRM_INVALID_REQUEST           =>  6,
	  SRM_SPACE_LIFETIME_EXPIRED    =>  7,
	  SRM_EXCEED_ALLOCATION         =>  8,
	  SRM_NO_USER_SPACE             =>  9,
	  SRM_NO_FREE_SPACE             => 10,
	  SRM_INTERNAL_ERROR            => 11,
	  SRM_NOT_SUPPORTED             => 12,
	  SRM_FAILURE                   => 13,   
          SRM_ABORTED                   => 14,
	  Default                       => 99,
	);

our %fts_states = 
    (
	  SRM_SUCCESS                   => 'Finished',
	  SRM_REQUEST_QUEUED            => 'Pending',
	  SRM_REQUEST_INPROGRESS        => 'Active',
	  SRM_PARTIAL_SUCCESS           => 'FinishedDirty',
	  SRM_AUTHENTICATION_FAILURE    => 'Failed',
	  SRM_AUTHORIZATION_FAILURE     => 'Failed',
	  SRM_INVALID_REQUEST           => 'Failed',
	  SRM_SPACE_LIFETIME_EXPIRED    => 'Failed',
	  SRM_EXCEED_ALLOCATION         => 'Failed',
	  SRM_NO_USER_SPACE             => 'Failed',
	  SRM_NO_FREE_SPACE             => 'Failed',
	  SRM_INTERNAL_ERROR            => 'undefined',
	  SRM_NOT_SUPPORTED             => 'Failed',
	  SRM_FAILURE                   => 'Failed',
          SRM_ABORTED                   => 'Failed',
          SRM_RELEASED                  => 'Failed',
          SRM_DUPLICATION_ERROR         => 'Failed',
          SRM_INVALID_PATH              => 'Failed',
          SRM_FILE_UNAVAILABLE          => 'Failed',
          SRM_FILE_BUSY                 => 'Failed',
          SRM_FILE_LOST                 => 'Failed',
	  undefined                     => 'undefined',
    );

our %weights =
	(
	  Ready	  =>  1 + 0 * 300,
	  Active  =>  1 + 0 * 300,
	  Waiting =>  1 + 0 * 900,
	);

# This function is perl magic and should not be touched; copy/pasted
# from Glite.pm
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

# This function is perl magic and should not be touched; copy/pasted
# from Glite.pm
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
  my ($cmd,$cmd2,$job,$state,%result,@raw,);
  
  $cmd = "srm-transfer-list -2 " . $self->{SERVICE};
  $cmd2 = "srm-transfer-status -2 " . $self->{SERVICE};
  
  open GLITE, "$cmd 2>/dev/null |" or do
  {
      print "$cmd: $!\n";
      $result{ERROR} = 'ListQueue: ' . $self->{SERVICE} . ': ' . $!;
      return \%result;
  };
  while ( <GLITE> )
  {
    push @raw, $_;
    # Each line will look like this:
    # Request token=-2147232194 Created=null
    # The below regexp plucks out the token.
    m%^Request token=([0-9,a-f,-]+)\s+(\S+)$% or next;
    $job = $1;
    $result{$job} = { ID => $job, STATE => "undefined", SERVICE => $self->{SERVICE} };
    # Now, look up the status
    open SRM_STATUS, "$cmd2 2>/dev/null |" or do
  	{
      print "$cmd: $!\n";
      next;
  	};
	$state = <SRM_STATUS>;
  	chomp $state if (defined $state);
  	$result{$job} = $fts_states{$state} || 'undefined';
    close SRM_STATUS or do 
    {
    	print "close: $cmd2: $1\n";
    } 
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
  my ($key,$value,$status,$fts_status,$target);

  print "Listing job $job\n";

  $cmd = "srm-transfer-status -2 " . $job->Service . ' ' . $job->ID;
  open GLITE, "$cmd 2>/dev/null |" or do
  {
      print "$cmd: $!\n";
      $result{ERROR} = 'ListJob: ' . $job->ID . ': ' . $!;
      return \%result;
  };
  # srm-transfer-status looks up the status of a single file; should look
  # something like this:
  #   $srm-transfer-status -2 srm://srm.unl.edu:8443/srm/managerv2 -2147244134
  #   SRM_SUCCESS
  $state = <GLITE>;
  chomp $state if (defined $state);
  # Convert from SRM state to FTS state.
  print "State returned by SRM: $state.\n";
  $state = $fts_states{$state};
  $state = $state || 'undefined';
  $result{JOB_STATE} = $state;

  $self->Dbgmsg("Job $job state $state.");

  my $time = time;
  my ($matching,%file_status,$new_value);
  %file_status = ();
  while (<GLITE>) {
  	if (length $_ == 1) {
  		if (defined $file_status{DESTINATION}) {
                        #Can't get this code to work.
			#$file_status{DURATION} ="Unavailable";
			#$file_status{RETRIES} = "Unavailable";
			#$file_status{TIMESTAMP} = time;
  			#$result{FILES}{$file_status{DESTINATION}} = (%file_status);
                        $result{FILES}{$file_status{DESTINATION}}{TIMESTAMP} = time;
                        $result{FILES}{$file_status{DESTINATION}}{DURATION} = "Unavailable";
                        $result{FILES}{$file_status{DESTINATION}}{RETRIES} = "Unavailable";
                        $result{FILES}{$file_status{DESTINATION}}{STATE} = $file_status{STATE};
                        $result{FILES}{$file_status{DESTINATION}}{REASON} = $file_status{REASON};
                        $result{FILES}{$file_status{DESTINATION}}{DESTINATION} = $file_status{DESTINATION};
                        $result{FILES}{$file_status{DESTINATION}}{SOURCE} = $file_status{SOURCE};
                        $result{FILE_STATES}{$file_status{STATE}}++;
		  	$self->Dbgmsg("File " . $file_status{DESTINATION} . " is in SRM state " . 
		  		$file_status{SRM_STATE} . "FTS 'state' " . $file_status{STATE} . ".  Reason:" . $file_status{REASON});
  		}
  	    %file_status = ();
    }
  	m%^(.+):\s+(.+)$% or next;
  	$key = $1;
  	$value = $2;
  	if ($key eq 'TargetSURL') {
  		$file_status{DESTINATION} = $value;
  	} elsif ($key eq 'SourceSURL') {
  		$file_status{SOURCE} = $value;
  	} elsif ($key eq 'FileStatus') {
  		$file_status{SRM_STATE} = $value;
  		$file_status{STATE} = $fts_states{$value} || 'undefined';
  		$result{FILE_STATES}{$fts_states{$value}}++;
  	}
  	elsif ($key eq 'StatusDescriptionBase64') {
  		$new_value = MIME::Base64::decode($value);
  		$file_status{REASON} = $new_value;
  	}
  }

  close GLITE or do
  {
      print "close: $cmd: $!\n";
      $result{ERROR} = 'close ListJob: ' . $job->ID . ':' . $!;
      return \%result;
  };
  
  $result{ETC} = 0;
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

  my $cmd = "srm-transfer-submit -2 -copyjobfile=" . $job->Copyjob;
      
  #print $self->Hdr,"Execute: $cmd\n";
  open GLITE, "$cmd 2>/dev/null |" or die "$cmd: $!\n";
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
      print "close: $cmd: $!\n";
      $result{ERROR} = 'close Submit: id=' . ( $id || 'undefined' ) . $!;
      return \%result;
  };
  print "Job $id submitted...\n";
  $result{ID} = $id;
  return \%result;
}

1;

