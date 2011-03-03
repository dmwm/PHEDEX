package PHEDEX::Monitoring::Notify::twitter;
use strict;
use warnings;
no strict 'refs';
use Net::Twitter::Lite;

sub new
{
  my ($proto,%h) = @_;
  my $class = ref($proto) || $proto;

  my $self = {};

  bless($self, $class);
  map { $self->{$_} = $h{$_} } keys %h;

  return $self;

}

# It send a tweet message to the phedex account in twitter

sub send_it {
  my ($self,$message) = @_;

# The Phedex Monitoring application is used
  my $nt = Net::Twitter::Lite->new(
                                   traits          => ['API::REST', 'OAuth'],
                                   consumer_key    => "cD7a1KFZKqHbX8SCi9DCg",
                                   consumer_secret => "tfIDmf3ooSsEBrx1ParKxcmWh5ShcIEWnUWFEbCdTQM",
                                  );

# This is the actual access information for the phedex account
  my ($access_token,$access_token_secret) = ('146000628-dohdHWSwDmF16VjiAlmKezDFjl6Wfme1RA6RcKA3',
                                             '0VDJXW2wDjkqgD6sKj6SaAFfm8ytACXwvM7fTCkqGU');

# access is passed to the api 
  $nt->access_token($access_token);
  $nt->access_token_secret($access_token_secret);
  
# message is tweeted
  my $tweet = "#$self->{PHEDEX_SITE} $message";
  eval { $nt->update({ status => $tweet }); }; PHEDEX::Core::Logging::Logmsg($self,$@) if $@;

}

1;
