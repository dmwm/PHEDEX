package PHEDEX::Transfer::Backend::Interface::Glite;

=head1 NAME

PHEDEX::Transfer::Backend::Interface::Glite - PHEDEX::Transfer::Backend::Interface::Glite Perl module

=head1 SYNOPSIS

pending...

=head1 DESCRIPTION

pending...

=head1 METHODS

=over

=back

=head1 EXAMPLES

pending...

=head1 SEE ALSO...

=cut

use strict;
use warnings;

our %params =
	(
	  SERVICE	=> undef,	# Transfer service URL
	  CHANNEL	=> undef,	# Channel name to match
	  USERDN	=> undef,	# Restrict to specific user DN
	  VONAME	=> undef,	# Restrict to specific VO
	  SSITE		=> undef,	# Specify source site name
	  DSITE		=> undef,	# Specify destination site name
	  NAME		=> undef,	# Arbitrary name for this object
	);

our %states =
	(
	  Submitted		=> 11,
	  Ready			=> 10,
	  Active		=>  9,
	  Finished		=>  0,
	 'FinishedDirty'	=>  0,
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

sub hdr
{
  my $self = shift;
  my $name = $self->{NAME} || ref($self) || "(unknown object $self)";
  return scalar(localtime) . ': ' . $name . ' ';
}

sub ListQueue
{
  my $self = shift;
  my ($cmd,$job,$state,%result);

  $cmd = "glite-transfer-list -s " . $self->{SERVICE};
  open GLITE, "$cmd |" or do
  {
    warn "$cmd: $!\n";
    $result{ERROR} = $!;
    return \%result;
  };
  while ( <GLITE> )
  {
    m%^([0-9,a-f,-]+)\s+(\S+)$% or next;
    $result{$1} = $2;
  }
  close GLITE or do
  {
    warn "close: $cmd: $!\n";
    $result{ERROR} = $!;
    return \%result;
  };
  return \%result;
}

sub ListJob
{
  my ($self,$job) = @_;
  my ($cmd,$state,%result,$dst,@raw);
  my ($key,$value);

  $cmd = "glite-transfer-status -l -s " . $job->{SERVICE} . ' ' . $job->ID;
  open GLITE, "$cmd |" or do
  {
    warn "$cmd: $!\n";
    $result{ERROR} = $!;
    return \%result;
  };
  $state = <GLITE>;
  chomp $state;
  $result{JOB_STATE} = $state || 'undefined';

  my (@h,$h);

  while ( <GLITE> )
  {
    push @raw, $_;
    if ( m%^\s+Source:\s+(.*)\s*$% )
    {
#     A 'Source' line is the first in a group for a single src->dst transfer
      push @h, $h if $h;
      undef $h;
    }
    if ( m%^\s+(\S+):\s+(.*)\s*$% ) { $h->{uc $1} = $2; }
  }
  close GLITE or do
  {
    warn "close: $cmd: $!\n";
    $result{ERROR} = $!;
    return \%result;
  };
  $result{RAW_OUTPUT} = \@raw;

  push @h, $h if $h;
  foreach $h ( @h )
  {
#  Be paranoid about the fields I read!
    foreach ( qw / DESTINATION DURATION REASON RETRIES SOURCE STATE / )
    {
      die "No \"$_\" key! : ", map { "$_=$h->{$_} " } sort keys %{$h}
        unless defined($h->{$_});
      $result{FILES}{$h->{DESTINATION}} = $h;
    }
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

sub StatePriority
{
  my ($self,$state) = @_;
  return $states{$state} if defined($states{$state});
  return $states{Default} if !$self->{DEBUGGING};
  die "Unknown state \"$state\" encountered in ",__PACKAGE__,"\n";
}

sub Submit
{
  my ($self,$job) = @_;
  my (%result,$id);

  defined $job->COPYJOB or do
  {
    $result{ERROR} = "No copyjob given: %h";
    return \%result;
  };

  my $cmd = "glite-transfer-submit -s " . $job->{SERVICE} .
				 ' -f ' . $job->COPYJOB;
# print $self->hdr,"Execute: $cmd\n";
  open GLITE, "$cmd |" or die "$cmd: $!\n";
  while ( <GLITE> ) { chomp; $id = $_ unless $id; }
  close GLITE or do
  {
    warn "close: $cmd: $!\n";
    $result{ERROR} = $!;
    return \%result;
  };
  print $self->hdr,"Job $id submitted...\n";

  $result{ID} = $id;
  return \%result;
}

1;
