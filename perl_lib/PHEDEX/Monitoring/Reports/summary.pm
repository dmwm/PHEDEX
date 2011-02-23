package PHEDEX::Monitoring::Reports::summary;
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

# It will generate a human readable summary based on the agent statistics information.
# this report is generate for all agents monitored by Watch Agent
# It is expected that output is return in a text string varable to be printed, mailed, etc.

sub generate_it {
  my ($self,%h) = @_;
  map { $self->{$_} = $h{$_} } keys %h;

  my $summary = "Statistics summary for all agents\n";
  foreach my $agent ( sort keys %{$self->{AGENTS}} )
  {
#   skip me
    next if $self->{AGENTS}{$agent}{self}{stats};
    $summary .= "Agent:$agent\t Total\t Delta(since last report)\n";
    $summary .= " User CPU Time\t\t $self->{AGENTS}{$agent}{resources}{utime}\t $self->{AGENTS}{$agent}{resources}{dutime}\n";
    $summary .= " System CPU Time\t $self->{AGENTS}{$agent}{resources}{stime}\t $self->{AGENTS}{$agent}{resources}{dstime}\n";
    $summary .= " Memory\t\t $self->{AGENTS}{$agent}{resources}{vsize}\t $self->{AGENTS}{$agent}{resources}{dvsize}\n";
    $summary .= "\n";
  }

  return $summary;
}

1;

