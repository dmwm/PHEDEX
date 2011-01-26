package PHEDEX::Monitoring::Reports::summary;
use strict;
use warnings;
no strict 'refs';
use Data::Dumper;

sub new
{
  my ($proto,%h) = @_;
  my $class = ref($proto) || $proto;

  my $self = {};

  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;

  print Dumper($self) if $self->{DEBUG};
  return $self;

}

sub generate_it {
  my ($self,%h) = @_;
  map { $self->{$_} = $h{$_} } keys %h;

  my $summary = "STATISTICS SUMMARY\n";
  foreach my $agent ( sort keys %{$self->{AGENTS}} )
  {
#   skip me
    next if $self->{AGENTS}{$agent}{self}{stats};
    $summary .= "\t $agent: \n";
    foreach my $key ( keys %{$self->{AGENTS}{$agent}{resources}} )
    {
       $summary .= "\t \t $key = $self->{AGENTS}{$agent}{resources}{$key} \n";
    } 
  }

  return $summary;
}

1;

