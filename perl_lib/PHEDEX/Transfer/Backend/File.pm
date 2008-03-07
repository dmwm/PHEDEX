package PHEDEX::Transfer::Backend::File;

=head1 NAME

PHEDEX::Transfer::Backend::File - PHEDEX::Transfer::Backend::File Perl module

=head1 SYNOPSIS

Collects parameters for a single file-transfer

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

our %params =
	(
	  MAX_TRIES	=> 3,		# Max number of tries
	  TIMEOUT	=> 0,		# Timeout per transfer attempt
	  PRIORITY	=> 1000,	# Priority for file transfer
	  RETRY_MAX_AGE	=> 3600,	# Timeout for retrying after errors
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
	  RETRIES	=> 0,		# Number of retries so far
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

sub LOG
{
  my $self = shift;
  push @{$self->{LOG}}, join(' ',@_,"\n") if @_;

  return undef unless defined $self->{LOG};
  return @{$self->{LOG}} if wantarray;
  return join('',@{$self->{LOG}});
}

sub STATE
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

sub EXIT_STATES
{
  return \%PHEDEX::Transfer::Backend::File::exit_states;
}

sub RETRY
{
  my $self = shift;
  $self->{RETRIES}++;
  return 0 if $self->{RETRIES} >= $self->{MAX_TRIES};
  undef $self->{STATE};
  $self->LOG(time,'reset for retry');
  return $self->{RETRIES};
}

sub NICE
{
  my $self = shift;
  my $nice = shift || -4;
  $self->{PRIORITY} += $nice;
}

sub WRITE_LOG
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
            scalar $self->LOG,
            scalar localtime time," Log ends\n";
  close $fh;
}

1;
