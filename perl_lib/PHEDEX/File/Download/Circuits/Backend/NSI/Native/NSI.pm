package PHEDEX::File::Download::Circuits::Backend::NSI::Native::NSI;

use strict;
use warnings;

use base 'PHEDEX::File::Download::Circuits::Backend::Core::Core','PHEDEX::Core::Logging';

use HTTP::Status qw(:constants);
use POE;
use SOAP::Lite;
use Switch;



# Data plane is activated when PSM is in provisioned state and during an active reservation period
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = (
        CIRCUITS            =>  undef, 
        HTTP_CLIENT         =>  undef,        
    );

    my %args = (@_);

    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    # Start the HTTP client
    $self->{HTTP_CLIENT} = PHEDEX::File::Download::Circuits::Backend::Helpers::HttpClient->new();
    $self->{HTTP_CLIENT}->spawn();

    bless $self, $class;
    return $self;
}

# Init POE events
# declare event 'processToolOutput' which is passed as a postback to External
# call super
sub _poe_init
{
    my ($self, $kernel, $session) = @_;

    $kernel->state('handleRequestReply', $self);
    $kernel->state('handlePollReply', $self);
    $kernel->state('handleTeardownReply', $self);
    $kernel->state('requestStatusPoll', $self);
    
    # Parent does the main initialization of POE events
    $self->SUPER::_poe_init($kernel, $session);
}