package PHEDEX::Transfer::Backend::File;

=head1 NAME

PHEDEX::Transfer::Backend::File - PHEDEX::Transfer::Backend::File Perl module

=head1 SYNOPSIS

A simple object that collects parameters for a single file-transfer

=head1 DESCRIPTION

This module is intended to make file-transfer management easier by proving
a placeholder for individual source->destination information. Arrays of these
objects will then be used by the L<PHEDEX::Transfer::Backend::Job|PHEDEX::Transfer::Backend::Job> module to build transfer-jobs.

=head1 METHODS

=cut

use strict;
use warnings;

our %params =
	(
	  MAX_TRIES	=> 3,		# Max number of tries
	  TIMEOUT	=> 0,		# Timeout per transfer attempt
	  PRIORITY	=> 1000,	# Priority for file transfer
	  RETRY_MAX_AGE	=> 3600,	# Timeout for retrying after errors
	  LOG		=> undef,	# A Log array...
	  RETRIES	=> 0,		# Number of retries so far
	  DURATION	=> undef,	# Time taken for this transfer
	  REASON	=> undef,	# Reason for failure, if any
	  START		=> undef,	# Time this file was created
	);

# These are not allowed to be set by the Autoloader...
our %ro_params =
	(
	  SOURCE	=> undef,	# Source URL
	  DESTINATION	=> undef,	# Destination URL
	  TASKID        => undef,       # PhEDEx Task ID
 	  FROM_NODE     => undef,       # PhEDEx source node
 	  TO_NODE       => undef,       # PhEDEx destination node
	  WORKDIR       => undef,       # workdir of a job(!)         
	  TIMESTAMP	=> undef,	# Time of file status reporting
	  STATE		=> 'undefined',	# Initial file state
	);

our %exit_states =
	(
	  Submitted	=> 0,
	  Active	=> 0,
	  Ready		=> 0,
	  Pending	=> 0,
	  Waiting	=> 0,
	  Done		=> 1,
	  Finishing	=> 0,
	  Finished	=> 1,
	  Canceled	=> 2,
	  Failed	=> 2,
	  Hold		=> 0,
	  undefined	=> 0,
	);

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self  = ref($proto) ? $class->SUPER::new(@_) : {};

  my %args = (@_);
  map {
        $self->{$_} = defined($args{$_}) ? delete $args{$_} : $params{$_}
      } keys %params;
  map {
        $self->{$_} = defined($args{$_}) ? delete $args{$_} : $ro_params{$_}
      } keys %ro_params;
  map { $self->{$_} = $args{$_} } keys %args;
  $self->{LOG} = [];

  bless $self, $class;
  return $self;
}

sub AUTOLOAD
{
  my $self = shift;
  my $attr = our $AUTOLOAD;
  $attr =~ s/.*:://;

  return $self->{$attr} if exists $ro_params{$attr};

  if ( exists($params{$attr}) )
  {
    $self->{$attr} = shift if @_;
    return $self->{$attr};
  }

  return unless $attr =~ /[^A-Z]/;  # skip DESTROY and all-cap methods
  my $parent = "SUPER::" . $attr;
  $self->$parent(@_);
}

=head2 Log

The C<< Log >> is an internal array of strings that record the progress of
the job through the transfer system. You can call the C<< Log >> method
with an array of strings and those strings will be appended to the log, so
you can build up a complete record of significant events in the life of
the job.

If called with a no arguments, the method returns the current contents of
the log, either as an array or joined into a single scalar, depending on
the return context.

If called with an array of strings, they are concatenated with a single
space, and a newline is added to the last line. e.g:

=over

  $file->Log("Start log...");
  $file->Log("File begins:","file does something...","file ends");
  print $file->Log; # prints two lines

=back

=cut


sub Log
{
  my $self = shift;
  push @{$self->{LOG}}, join(' ',@_,"\n") if @_;

# return undef unless defined $self->{LOG};
  return @{$self->{LOG}} if wantarray;
  return join('',@{$self->{LOG}});
}

=head2 State

The current file-state is set or returned by this method. It can be called
with 0, 1, or 2 arguments. With only one argument, the current state is
returned. With two arguments, the second argument is taken to be the
string name of the file state, and the state is set accordingly. The time
the state is set is recorded in the job, and is retrievable with the C<<
Timestamp() >> method. With three arguments, the third argument is taken
to be the timestamp for this state-change (epoch seconds).

When setting the state, the previous state will be returned if the state
is changed, or C<< undef >> will be returned if the state doesn't change
(i.e. the new state is equal to the old state).

=over

  $file->State('Initial');
  print $file->State('Next_state'); # prints 'Initial'
  print $file->State('Next_state'); # prints nothing
  print $file->State();             # prints 'Next_state'

=back

=cut

sub State
{
  my ($self,$state,$time) = @_;
  return $self->{STATE} unless $state;
  return undef unless $self->{STATE};
 
  if ( $state ne $self->{STATE} )
  {
    my $oldstate = $self->{STATE};
    $self->{STATE} = $state;
    $self->{TIMESTAMP} = $time || time;
    return $oldstate;
  }
  return undef;
}

=head2 ExitStates

return a reference to a hash keyed on known file-states. The hash values
are zero for non-terminal states, non-zero for terminal states. This is
technology dependent, and should probably go into the backend...?

=cut

sub ExitStates { return \%PHEDEX::Transfer::Backend::File::exit_states; }

=head2 Retry

Takes no arguments, simply resets a file-state for retrying a transfer. 
Returns zero (and doesn't reset the state) if the maximum number of 
retries is exceeded, or returns the number of the retry. Use C<< MaxTries >> to 
set/get the maximum number of allowed retries, and C<< Retries >> to get the
current retry count.

=cut

sub Retry
{
  my $self = shift;
  $self->{RETRIES}++;
  return 0 if $self->{RETRIES} >= $self->{MAX_TRIES};
  undef $self->{STATE};
  $self->Log(time,'reset for retry');
  return $self->{RETRIES};
}

=head2 Retries

Get the current retru-count for a file.

=cut

sub Retries
{
  my $self = shift;
  return $self->{RETRIES};
}

=head2 Nice

Set/get the 'nice' value for a transfer. I have no idea why this is here.

=cut

sub Nice
{
  my $self = shift;
  my $nice = shift || -4;
  $self->{PRIORITY} += $nice;
}

=head2 WriteLog

Takes a directory as argument, and writes the current C<< Log >> contents 
to a logfile derived from the destination file name.

=cut

sub WriteLog
{
  my $self = shift;
  my $dir = shift;
  return unless $dir;

  my ($fh,$logfile);
  $logfile = $self->{DESTINATION};
  $logfile =~ s%^.*/store%%;
  $logfile =~ s%^.*=%%;
  $logfile =~ s%\/%_%g;
  $logfile = $dir . '/file-' . $logfile . '.log';
  open $fh, ">$logfile" || die "open: $logfile: $!\n";
  print $fh scalar localtime time, ' Log for ',$self->{DESTINATION},"\n",
            $self->Log,
            scalar localtime time," Log ends\n";
  close $fh;
}

=head2 Timeout

Set/get the value of the timeout for a given job to complete. Not actually 
used anywhere yet!

=cut

sub Timeout
{
  my $self = shift;
  $self->{TIMEOUT} = shift if @_;
  return $self->{TIMEOUT};
}

=head2 Priority

Set/get the 'priority' for monitoring a given job. Priorities, in this 
context, are used to determine which job to monitor next. The job with the 
lowest priority will be checked next.

Setting the Priority is only meaningful before a job is submitted. After 
that, the priority is adjusted automatically according to the state of the 
job, based on as-yet unfinished algorithms that make sure that jobs which 
will finish soon will be monitored more closely than jobs that will not 
finish for some long time. You can retrieve the priority at any time to 
get some rank-estimate of when this particular job will finish, if you 
know the details of the algorithm in use.

=cut

sub Priority
{
  my $self = shift;
  $self->{PRIORITY} = shift if @_;
  return $self->{PRIORITY};
}

=head2 MaxTries

Set/get the maximum number of tries for a given file-transfer. Note: 
tries, not retries. The first try counts as one!

Not sure if this is still relevant...

=cut

sub MaxTries
{
  my $self = shift;
  $self->{MAX_TRIES} = shift if @_;
  return $self->{MAX_TRIES};
}

=head2 Source

Set/get the source-file PFN

=cut

sub Source
{
  my $self = shift;
  $self->{SOURCE} = shift if @_;
  return $self->{SOURCE};
}

=head2 Destination

Set/get the destination-file PFN

=cut

sub Destination
{
  my $self = shift;
  $self->{DESTINATION} = shift if @_;
  return $self->{DESTINATION};   
}

=head2 TaskID

Set/get the PhEDEx Task ID

=cut

sub TaskID
{
  my $self = shift;
  $self->{TASKID} = shift if @_;
  return $self->{TASKID};
}

=head2 FromNode

Set/get the PhEDEx source node

=cut

sub FromNode
{
  my $self = shift;
  $self->{FROM_NODE} = shift if @_;
  return $self->{FROM_NODE};
}

=head2 ToNode

Set/get the destination-file PFN

=cut

sub ToNode
{
  my $self = shift;
  $self->{TO_NODE} = shift if @_;
  return $self->{TO_NODE};
}

=head2 Workdir

Set/get the job's working directory. Not sure why the File needs this???

=cut

sub Workdir
{
  my $self = shift;
  $self->{SOURCE} = shift if @_;
  return $self->{SOURCE};
}

=head2 Timestamp

Return the unix epoch time at which the current file state was set. To 
change the timestamp, use the C<< State >> method, and change the state.

=cut

sub Timestamp
{
  my $self = shift;
  $self->{TIMESTAMP} = shift if @_;
  return $self->{TIMESTAMP};
}

=head2 Reason

Set/return the reason for a file-transfer-failure.

=cut

sub Reason
{
  my $self = shift;
  $self->{REASON} = shift if @_;
  return $self->{REASON};
}

=head2 Duration

Set/return the duration for a file-transfer.

=cut

sub Duration
{
  my $self = shift;
  $self->{DURATION} = shift if @_;
  return $self->{DURATION};
}

=head2 Start

Set/return the start-time for a file-transfer.

=cut

sub Start
{
  my $self = shift;
  $self->{START} = shift if @_;
  return $self->{START};
}

=head2 RetryMaxAge

Set/return the RetryMaxAge for a file-transfer.

=cut

sub RetryMaxAge
{
  my $self = shift;
  $self->{RETRY_MAX_AGE} = shift if @_;
  return $self->{RETRY_MAX_AGE};
}

1;
