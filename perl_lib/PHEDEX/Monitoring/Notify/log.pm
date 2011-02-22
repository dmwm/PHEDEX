package PHEDEX::Monitoring::Notify::log;
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

sub send_it {
  my ($self,$message) = @_;
  PHEDEX::Core::Logging::Logmsg($self,$message);
}

1;

