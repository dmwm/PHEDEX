package PHEDEX::Transfer::Backend::Job;

=head1 NAME

PHEDEX::Transfer::Backend::Job - PHEDEX::Transfer::Backend::Job Perl module

=head1 SYNOPSIS

Collects parameters for a single file-transfer job

=head1 DESCRIPTION

pending...

=head1 METHODS

=over

=back

=head1 EXAMPLES

pending...

=head1 SEE ALSO...

L<PHEDEX::Core::Agent|PHEDEX::Core::Agent>, 

=cut

use strict;
use warnings;
use File::Temp qw/ tempfile tempdir /;

our %params =
	(
	  ID		=> undef,	# Determined when the job is submitted
	  SERVICE       => undef        # FTS endpoint - fix - need to make a derived class for FTS specific job?!
	  TIMEOUT	=>    0,	# Timeout for total job transfer
	  PRIORITY	=>    1,	# Priority for total job transfer
	  JOB_CALLBACK	=> undef,	# Callback per job state-change
	  FILE_CALLBACK	=> undef,	# Callback per file state-change
	  FILES		=> undef,	# A PHEDEX::Transfer::Backend::File array
	  COPYJOB	=> undef,	# Name of copyjob file
	  WORKDIR	=> undef,	# Working directory for this job
	  RAW_OUTPUT	=> undef,	# Raw output of status command
	  SUMMARY	=> '',		# Summary of job-status so far
	);

# These are not allowed to be set by the Autoloader...
our %ro_params =
	(
	  TIMESTAMP	=> undef,	# Time of job status reporting
	  TEMP_DIR	=> undef,	# Directory for temporary files
	  STATE		=> 'undefined'	# Initial job state
	);

our %exit_states =
	(
	  Submitted		=> 0,
	  Pending		=> 0,
	  Active		=> 0,
	  Ready			=> 0,
	  Done			=> 1,
	  DoneWithErrors	=> 1,
	  Failed		=> 1,
	  Finishing		=> 0,
	  Finished		=> 1,
	  FinishedDirty		=> 1,
	  Canceling		=> 0,
	  Canceled		=> 1,
	  undefined		=> 1,
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

  bless $self, $class;
  $self->LOG(time,'created...');
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

sub LOG
{
  my $self = shift;
  push @{$self->{LOG}}, join(' ',@_,"\n") if @_;

  return @{$self->{LOG}} if wantarray;
  return join('',@{$self->{LOG}});
}

sub STATE
{
  my ($self,$state) = @_;
  return $self->{STATE} unless $state;

  if ( $state ne $self->{STATE} )
  {
    $self->{STATE} = $state;
    $self->{TIMESTAMP} = shift || time;
  }
}

sub FILES
{
  my $self = shift;
  return $self->{FILES} unless @_;
  foreach ( @_ )
  {
    if ( exists $self->{FILES}{ $_->DESTINATION } )
    {
#     I get here if a duplicate file is found!
#     $DB::single=1;
      print 'Duplicate file ',$_->DESTINATION," for this job\n";
    }
    $self->{FILES}{ $_->DESTINATION } = $_;
  }
}

sub PREPARE
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
}

sub EXIT_STATES
{
  return \%PHEDEX::Transfer::Backend::Job::exit_states;
}

1;
