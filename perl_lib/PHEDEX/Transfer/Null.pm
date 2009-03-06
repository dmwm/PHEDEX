package PHEDEX::Transfer::Null;
use strict;
use warnings;
use base 'PHEDEX::Transfer::Core', 'PHEDEX::Core::Logging';
use PHEDEX::Core::Command;
use PHEDEX::Core::Timing;
use Data::Dumper;
use POE;

# Special back end that bypasses transfers entirely.  Good for testing.
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $master = shift;

    # Get derived class arguments and defaults
    my $options = shift || {};
    my $params = shift || {};

    # Set my defaults where not defined by the derived class.
    $params->{PROTOCOLS}   ||= [ 'srm' ];    # Accepted protocols
    $params->{BATCH_FILES} ||= 100;          # Max number of files per batch
    $params->{FAIL_CODE}  ||= 28;             # Return code on failure (>0 for halting failure, <0 for continuing)
    $params->{FAIL_RATE}  ||= 0;              # Probability of failure (0 to 1)
    $params->{FAIL_LINKS} ||= {};            # Probability to fail per link (0 to 1)
    $params->{FAIL_CONFIG} ||= undef;        # Config file for failure rates

    # Set argument parsing at this level.
    $options->{'batch-files=i'}      = \$params->{BATCH_FILES};
    $options->{'fail-code=i'}        = \$params->{FAIL_CODE};
    $options->{'fail-rate=f'}        = \$params->{FAIL_RATE};
    $options->{'fail-link=f'}        = $params->{FAIL_LINKS};
    $options->{'fail-config=s'}      = \$params->{FAIL_CONFIG};

    # Initialise myself
    my $self = $class->SUPER::new($master, $options, $params, @_);

    bless $self, $class;
    return $self;
}

sub setup_callbacks
{
  my ($self,$kernel,$session) = @_; #[ OBJECT, KERNEL, SESSION ];

  return unless $self->{FAIL_CONFIG};

# Try to load a FileWatcher if there is an external config file
  eval("use T0::FileWatcher");
  if ( $@ )
  {
    $self->Warn("Failed to load the T0::FileWatcher module: $@\n");
    undef $self->{FAIL_CONFIG};
    return;
  }

  $kernel->state( '_child', $self );
  $kernel->state( 'ReadConfig', $self );
  my %watcher_args = (  File     => $self->{FAIL_CONFIG},
                        Interval => 3,
                        Object   => $self,
                        Event    => 'ReadConfig',
                     );
  $self->{Watcher} = T0::FileWatcher->new( %watcher_args );
  $kernel->yield( 'ReadConfig' );
}

sub _child
{
# Dummy routine for unused event-handler
# print "_child called, ignored...\n";
}
sub ConfigRefresh { return 3; }
sub Config { return (shift)->{FAIL_CONFIG}; }

sub ReadConfig
{
# (re-)read the configuration file to update dynamic parameters.
  my $self = $_[ OBJECT ];
  $self->Logmsg("\"",$self->{FAIL_CONFIG},"\" may have changed...");

  my $file = $self->{FAIL_CONFIG};
  return unless $file;
  T0::Util::ReadConfig($self,'Failure::Rates',$file);

  $Data::Dumper::Terse=1;
  $Data::Dumper::Indent=0;
  my $a = Data::Dumper->Dump([\%Failure::Rates]);
  $a =~ s%\n%%g;
  $a =~ s%\s\s+% %g;
  $self->Alert("Setting new failure rates: $a");

  if ( defined($self->{Watcher}) )
  {
    my $refresh = $self->{ConfigRefresh};
    $self->{Watcher}->Interval( $refresh ) if $refresh;
    $self->{Watcher}->Options( %FileWatcher::Params );
  }
}

# No-op transfer batch operation.
sub start_transfer_job
{
    my ( $self, $kernel, $jobid ) = @_[ OBJECT, KERNEL, ARG0 ];

    my $job = $self->{JOBS}->{$jobid};
    my $now = &mytimeofday();

    foreach my $taskid (keys %{$job->{TASKS}})
    {
	my $task = $job->{TASKS}->{$taskid};

	my $info;
	my $fail_rate;
	if (exists $task->{FROM_NODE} &&
	    exists $self->{FAIL_LINKS}->{ $task->{FROM_NODE} } ) {
	    $fail_rate = $self->{FAIL_LINKS}->{ $task->{FROM_NODE} };
	}
	$fail_rate ||= $self->{FAIL_RATE};
	$fail_rate ||= 0;

	if (rand() < $fail_rate) {
	    $info = { START => $now, END => $now, STATUS => $self->{FAIL_CODE},
		      DETAIL => "nothing done unsuccessfully", LOG => "ERROR" };
	} else {
	    $info = { START => $now, END => $now, STATUS => 0,
		      DETAIL => "nothing done successfully", LOG => "OK" };
	}
	$kernel->yield('transfer_done', $taskid, $info);
    }
}

1;
