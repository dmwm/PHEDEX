package PHEDEX::Transfer::Backend::Job;

=head1 NAME

PHEDEX::Transfer::Backend::Job - PHEDEX::Transfer::Backend::Job Perl module

=head1 SYNOPSIS

A simple object that collects parameters for a single file-transfer job

=head1 DESCRIPTION

This module is intended to make job-management for the transfer backends
easier by providing a place-holder to store information about individual
transfer jobs, whatever the technology or details. As such, it has a number
of data-methods (setters and getters) but very few behavioural methods.

=head1 METHODS

=cut

use strict;
use warnings;
use File::Temp qw/ tempfile tempdir /;

our %params =
	(
	  ID		=> undef,	# Determined when the job is submitted
	  SERVICE       => undef,       # FTS endpoint - backend specific!
	  TIMEOUT	=>     0,	# Timeout for total job transfer
	  PRIORITY	=>     3,	# Priority for total job transfer
	  JOB_POSTBACK	=> undef,	# Callback per job state-change
	  FILE_POSTBACK	=> undef,	# Callback per file state-change
	  FILES		=> undef,	# A PHEDEX::Transfer::Backend::File array
	  SPACETOKEN	=> undef,	# A space-token for this job
	  COPYJOB	=> undef,	# Name of copyjob file
	  WORKDIR	=> undef,	# Working directory for this job
	  LOG           => undef,	# Internal log
	  RAW_OUTPUT	=> undef,       # Raw output of status command
	  SUMMARY	=> '',		# Summary of job-status so far
	  VERBOSE	=>     0,		# Verbosity for Transfer::Backend::Interface commands
	);

# These are not allowed to be set by the Autoloader...
our %ro_params =
	(
	  TIMESTAMP	=> undef,	# Time of job status reporting
	  TEMP_DIR	=> undef,	# Directory for temporary files
	  STATE		=> 'undefined',	# Initial job state
	  ME		=> undef,	# A name for this job. == ID!
	);

our %exit_states =
	(
	  Submitted		=> 0,
	  Pending		=> 0,
	  Active		=> 0,
	  Ready			=> 0,
	  Done			=> 0,
	  DoneWithErrors	=> 0,
	  Failed		=> 1,
	  Finishing		=> 0,
	  Finished		=> 1,
	  FinishedDirty		=> 1,
	  Canceling		=> 0,
	  Canceled		=> 1,
	  undefined		=> 0,
	  lost			=> 1,
	  abandoned		=> 1,
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
  $self->{RAW_OUTPUT} = [];
  $self->{ME} = $self->{ID}; # in case it's already set...
  bless $self, $class;
  $self->Log(time,'created...');
  $self->Timestamp(time);
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

sub DESTROY
{
  my $self = shift;

  return unless $self->{COPYJOB};
# unlink $self->{COPYJOB} if -f $self->{COPYJOB};
# print $self->{ID},": Unlinked ",$self->{COPYJOB},"\n";
  $self = {};
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

  $job->Log("Start log...");
  $job->Log("Job begins:","job does something...","job ends");
  print $job->Log; # prints two lines

=back

=cut

sub Log
{
  my $self = shift;
  push @{$self->{LOG}}, join(' ',@_,"\n") if @_;

  return @{$self->{LOG}} if wantarray;
  return join('',@{$self->{LOG}});
}

=head2 RawOutput

When the status of a job is polled using the queue interface, the raw 
output of the polling command is stored in the C<< RAW_OUTPUT >> 
attriubute, accessible through this function. Like C<< Log >>, the output 
is returned as an array of text lines or as a single concatenated line, 
depending on the return context. This is useful for recording the gory 
details for debugging purposes.

=cut

sub RawOutput
{
  my $self = shift;
  foreach ( @_ )
  {
    chomp;
    push @{$self->{RAW_OUTPUT}}, $_ . "\n";
  }
#  $self->{RAW_OUTPUT} = [ @_ ] if @_;

  return @{$self->{RAW_OUTPUT}} if wantarray;
  return join('',@{$self->{RAW_OUTPUT}});
}

=head2 State

The current job-state is set or returned by this method. It can be called 
with 0, 1, or 2 arguments. With only one argument, the current state is 
returned. With two arguments, the second argument is taken to be the 
string name of the job state, and the state is set accordingly. The time 
the state is set is recorded in the job, and is retrievable with the C<< 
Timestamp() >> method. With three arguments, the third argument is taken 
to be the timestamp for this state-change (epoch seconds).

When setting the state, the previous state will be returned if the state 
is changed, or C<< undef >> will be returned if the state doesn't change 
(i.e. the new state is equal to the old state).

=over

  $job->State('Initial');
  print $job->State('Next_state'); # prints 'Initial'
  print $job->State('Next_state'); # prints nothing
  print $job->State();             # prints 'Next_state'

=back

=cut

sub State
{
  my ($self,$state,$timestamp) = @_;
  return $self->{STATE} unless $state;
  return undef unless $self->{STATE};

  if ( $state ne $self->{STATE} )
  {
    my $oldstate = $self->{STATE};
    $self->{STATE} = $state;
    $self->{TIMESTAMP} = $timestamp || time;
    return $oldstate;
  }
  return undef;
}

=head2 Files

Set or get the array of 
L<PHEDEX::Transfer::Backend::File|PHEDEX::Transfer::Backend::File> objects 
associated with this job. Set the files by calling with an array of 
references to C<< PHEDEX::Transfer::Backend::File >> objects. If called 
with no arguments, returns a hashref which has transfer-destinations as 
keys and C<< PHEDEX::Transfer::Backend::File >> references as the
corresponding values.

=cut

sub Files
{
  my $self = shift;
  return $self->{FILES} unless @_;
  foreach ( @_ )
  {
    if ( exists $self->{FILES}{ $_->DESTINATION } )
    {
#     I get here if a duplicate file is found!
      print 'Duplicate file ',$_->DESTINATION," for this job\n";
    }
    $self->{FILES}{ $_->DESTINATION } = $_;
  }
}

=head2 Dump

Write a Data::Dumper dump of the job to an external file. Assumes WORKDIR
has been set, and is not protected against any of a number of things that
might possibly go wrong. Used to maintain job-definition across restarts
of the agent.

=cut

use Data::Dumper;
sub Dump
{
  my $self = shift;
  my ($file);
  $file = $self->{WORKDIR} . '/job-' . $self->{ID} . '.dump';

  open DUMP, "> $file" or $self->Fatal("Cannot open $file for dump of job");
  print DUMP Dumper($self);
  close DUMP;
}

=head2 Prepare

Write a copyjob file for the job, in the way that FTS expects (i.e. one 
line with "$source-pfn $destination-pfn" per file-transfer within the 
job). If the C<< Copyjob >> method has been called to specify a copyjob 
location (or it was set in the constructor) then that location will be 
used, overwriting any existing file. Otherwise, a new, unique filename 
will be generated, in the directory specified by C<< Tempdir >>, and the 
C<< COPYJOB >> attribute will be set accordingly.

=cut

sub Prepare
{
  my $self = shift;
  my ($fh,$file);

  if ( $file = $self->{COPYJOB} )
  {
    open FH, ">$file" or die "Cannot open file $file: $!\n";
    $fh = *FH;
  }
  else
  {
    ($fh,$file) = tempfile( undef ,
			    UNLINK => 1,
			    DIR => $self->{TEMP_DIR}
			  );
  }

# print "Using temporary file $filename\n";
  $self->{COPYJOB} = $file;
  foreach ( values %{$self->{FILES}} )
  { print $fh $_->SOURCE,' ',$_->DESTINATION,"\n"; }

  close $fh;
  return $file;
}

=head2 ExitStates

return a reference to a hash keyed on known job-states. The hash values 
are zero for non-terminal states, non-zero for terminal states. This is 
technology dependent, and should probably go into the backend...?

=cut

sub ExitStates { return \%PHEDEX::Transfer::Backend::Job::exit_states; }

=head2 ID

set or get the job ID. This should be the ID of the transfer system, not 
an internal PhEDEx ID.

=cut

sub ID
{
  my $self = shift;
  $self->{ID} = $self->{ME} = shift if @_;
  return $self->{ID};
}

=head2 Service

The Glite transfer interface requires a 'service' URL. This method allows 
to set/get that URL, which allows one Glite interface to serve many jobs 
in parallel.

=cut

sub Service
{
  my $self = shift;
  $self->{SERVICE} = shift if @_;
  return $self->{SERVICE};
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

=head2 Copyjob

Set/get the name of the C<< COPYJOB >> attribute. Should not be set once 
the job is submitted!

=cut

sub Copyjob
{
  my $self = shift;
  $self->{COPYJOB} = shift if @_;
  return $self->{COPYJOB};
}

=head2 Workdir

Set/get the working directory for this job, as set by the backend module
that creates the job.

=cut

sub Workdir
{
  my $self = shift;
  $self->{WORKDIR} = shift if @_;
  return $self->{WORKDIR};
}

=head2 Summary

Set/get a simple one-line summary of the job status.

=cut

sub Summary
{
  my $self = shift;
  $self->{SUMMARY} = shift if @_;
  return $self->{SUMMARY};
}

=head2 Timestamp

Return the unix epoch time at which the current job state was set. To 
change the timestamp, use the C<< State >> method, and change the state.

=cut

sub Timestamp
{
  my $self = shift;
  $self->{TIMESTAMP} = shift if @_;
  return $self->{TIMESTAMP};
}

=head2 Tempdir

Set/get the name of the temporary directory used to create the copyjob 
file. Probably redundant if we are going to specify the full path of the 
copyjob file instead, using the C<< Copyjob >> method.

=cut

sub Tempdir
{
  my $self = shift;
  $self->{Tempdir} = shift if @_;
  return $self->{Tempdir};
}

1;
