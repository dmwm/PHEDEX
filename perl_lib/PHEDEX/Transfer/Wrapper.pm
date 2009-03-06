package PHEDEX::Transfer::Wrapper;

##H Helper tool to oversee running of a transfer job.
##H
##H This tool monitors an actual transfer as long as the job runs,
##H handles the log output and generates the final transfer report
##H for each file in the copy job.  One instance of the tool is
##H started for every sub-process invocation (srmcp, etc.).
##H
##H Usage:
##H   TransferWrapper COPY-JOB-DIR TIMEOUT COMMAND [ARGS...]
##H
##H COPY-JOB-DIR is the download agent copy job directory.  It
##H contains all the state information about this particular job.
##H
##H COMMAND and ARGS are the command to execute.

use PHEDEX::Core::JobManager;
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use Data::Dumper;
use POE;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %h = @_;
  my $self = {};

  my %params = (
		WORKDIR => undef,
		TIMEOUT	=> undef,
		CMD	=> undef,
	       );
  map { $self->{$_} = $h{$_} || $params{$_} } keys %params;
  foreach ( keys %params )
  {
    die "No value for $_ parameter\n" unless defined $self->{$_};
  }
  die "$self->{WORKDIR}: no such directory\n" if ! -d $self->{WORKDIR};
  die "$self->{TIMEOUT}: not a valid timeout\n" if $self->{TIMEOUT} !~ /^\d+$/;
  undef $self->{TIMEOUT} unless $self->{TIMEOUT};
  bless $self,$class;

# Read the copy job information so we can prepare a report.
  $self->{COPYINFO} = do {
			   no strict "vars";
			   eval(&input("$self->{WORKDIR}/info") || '')
			 };
  die "$self->{WORKDIR}: corrupt info\n" if $@ ||
		 ! $self->{COPYINFO} || ! $self->{COPYINFO}{TASKS};

# Prepare job exit status holder and prepare saved info.
  $self->{JOBSTATUS} = $self->{SIGNALLED} = undef;
  $self->{START} = &mytimeofday();

  my $workdir = $self->{WORKDIR};
  unlink(<$$self{WORKDIR}/{command,log,time*,exit*,completed,signalled,live}>);
  &output("$self->{WORKDIR}/command", "@{$self->{CMD}}")
    or die "$self->{WORKDIR}/command: $!\n";
  &output("$self->{WORKDIR}/time-start", $self->{START})
    or die "$self->{WORKDIR}/time-start: $!\n";

# Redirect standard input, output and error.
  open(WRPOUT, ">> $workdir/wrapper-log");
#open(STDIN, "</dev/null");
#open(STDOUT, ">> $workdir/wrapper-log");
#open(STDERR, ">&STDOUT");

# Start the job.
  $self->{JOBMANAGER} = new PHEDEX::Core::JobManager(KEEPALIVE => 0);
  $self->{JOBMANAGER}->addJob(
				sub { $self->jobFinished($_[0]) }, 
				{ TIMEOUT => $self->{TIMEOUT},
				  LOGFILE => "$self->{WORKDIR}/log" },
				@{$self->{CMD}}
			     );

# Wait for the job to exit.  Indicate liveness.
  $SIG{INT} = $SIG{TERM} = sub { $self->{SIGNALLED} = shift;
				 $self->{JOBMANAGER}->killAllJobs() };
  return $self;
}

sub jobFinished
{
  my $self = shift;
  $self->{JOBSTATUS} = shift;
# Job status should now be set.
  die "$0: job status lost!\n" if ! $self->{JOBSTATUS};
  my $end = &mytimeofday();

# If we have a SRM transfer report, read that in now.
  my %taskstatus = ();
  if (-s "$self->{WORKDIR}/srm-report")
  {
      # Read in the report.
      my %reported;
      foreach (split (/\n/, &input("$self->{WORKDIR}/srm-report") || ''))
      {
          my ($from, $to, $status, @rest) = split(/\s+/);
          $reported{$from}{$to} = [ $status, "@rest" ];
      }

      # Read in tasks and correlate with report.
      foreach my $task (%{$self->{COPYINFO}{TASKS}})
      {
	  my $file = "$self->{WORKDIR}/../../tasks/$task";
	  my $info = do { no strict "vars"; eval (&input($file) || '') };
	  next if ! $info;

	  my ($from, $to) = @$info{"FROM_PFN", "TO_PFN"};
	  $taskstatus{$task} = $reported{$from}{$to};
      }
  }

  # Build per-task status update and write them out.
  my $log = &input("$self->{WORKDIR}/log");
  foreach my $task (keys %{$self->{COPYINFO}{TASKS}})
  {
      my $status = { START => $start, END => $end,
	             STATUS => $self->{JOBSTATUS}{STATUS},
		     DETAIL => "", LOG => $log };

      if ($taskstatus{$task})
      {
	  # We have a report entry, use that.
	  ($$status{STATUS}, $$status{DETAIL}) = @{$taskstatus{$task}};
      }
      elsif (defined $self->{SIGNALLED})
      {
	  # The wrapper itself got a signal.
	  $$status{STATUS} = -4;
	  $$status{DETAIL} = "transfer was terminated with signal $self->{SIGNALLED}";
      }
      elsif (exists $self->{JOBSTATUS}{SIGNAL})
      {
	  # The transfer timed out.
	  $$status{STATUS} = -5;
	  $$status{DETAIL} = "transfer timed out after $self->{JOBSTATUS}{TIMEOUT}"
			     . " seconds with signal $self->{JOBSTATUS}{SIGNAL}";
      }

      &output("$self->{WORKDIR}/T${task}X", Dumper($status))
          or die "$self->{WORKDIR}/T${task}X: $!\n";
  }

  # Generate some useful flags.
  if (defined $self->{SIGNALLED})
  {
      &output("$self->{WORKDIR}/signalled", $self->{SIGNALLED})
          or die "$self->{WORKDIR}/signalled: $!\n";
  }
  elsif (exists $self->{JOBSTATUS}{SIGNAL})
  {
      &output("$self->{WORKDIR}/timed-out", $self->{JOBSTATUS}{SIGNAL})
          or die "$self->{WORKDIR}/timed-out: $!\n";
  }
  &output("$self->{WORKDIR}/time-end", $end)
      or die "$self->{WORKDIR}/time-end: $!\n";
  &output("$self->{WORKDIR}/exit-code", $self->{JOBSTATUS}{STATUS})
      or die "$self->{WORKDIR}/exit-code: $!\n";
  &touch("$self->{WORKDIR}/completed");
}

1;
