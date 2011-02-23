package PHEDEX::Monitoring::Reports::tweet;
use strict;
use warnings;
no strict 'refs';

sub new
{
  my ($proto,%h) = @_;
  my $class = ref($proto) || $proto;

  my $self = {};

  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;

  return $self;

}

# Trying to generate a small message for tweeting

sub generate_it {
  my ($self,%h) = @_;
  map { $self->{$_} = $h{$_} } keys %h;

  my $summary = '';
  foreach my $agent ( sort keys %{$self->{AGENTS}} )
  {
#   skip me
    next if $self->{AGENTS}{$agent}{self}{stats};

    $summary .= "$agent ($self->{AGENTS}{$agent}{resources}{utime}s,";
    $summary .=         "$self->{AGENTS}{$agent}{resources}{stime}s,";
    $summary .=         "$self->{AGENTS}{$agent}{resources}{vsize}MB) ";
  }

  return $summary;
}

1;

