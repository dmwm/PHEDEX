package PHEDEX::Monitoring::Notify::log;
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

sub report {
  my ($self,$message) = @_;
  PHEDEX::Core::Logging::Logmsg($self,$message);
}

1;

