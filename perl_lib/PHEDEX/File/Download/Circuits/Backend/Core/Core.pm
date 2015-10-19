package PHEDEX::File::Download::Circuits::Backend::Core::Core;

use strict;
use warnings;

use base 'PHEDEX::Core::Logging';
use POE;
use List::Util qw(min);

my %params =
	(
        AGENT_TRANSLATION           =>  {},         # Stores the PhEDEx names to IDC ref
        SUPPORTED_RESOURCE          =>  undef,      # Set this in extending class
	);
		
sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my %args = (@_);
    #   use 'defined' instead of testing on value to allow for arguments which are set to zero.
    map { $args{$_} = defined($args{$_}) ? $args{$_} : $params{$_} } keys %params;
    my $self = $class->SUPER::new(%args);

    bless $self, $class;
    return $self;
}

# Initialize all POE events specifically related to circuits
sub _poe_init
{
  my ($self, $kernel, $session) = @_;

  # Declare events which are going to be used by the CircuitManager
  my @poe_subs = qw(backendRequestCircuit backendTeardownCircuit);

  $kernel->state($_, $self) foreach @poe_subs;
}

# Check if the node supports circuits. This shouldn't be called by the CircuitManager.
# Normally it should only be interested in the link itself. For that, use 'check_link_support'
sub checkNodeSupport {
    my ($self, $node) = @_;
    return (defined $node && $self->{AGENT_TRANSLATION}{$node}) ? 1 : 0;
}

# Checks if a link supports the creation of circuits
sub checkLinkSupport {
    my ($self, $from_node, $to_node) = @_;
    return $self->checkNodeSupport($from_node) && $self->checkNodeSupport($to_node);
}

# Returns the advertised bandwidth that can be had between the two provided nodes
sub getCircuitBandwidth {
    my ($self, $from_node, $to_node) = @_;
    return unless $self->checkLinkSupport($from_node, $to_node);
    return min $self->{AGENT_TRANSLATION}{$from_node}{BANDWIDTH}, $self->{AGENT_TRANSLATION}{$to_node}{BANDWIDTH};
}

# This method should be implemented by the backend child
# It will be called to request the creation of a circuit
sub backendRequestCircuit {
    my $self = shift;
    $self->Fatal("request not implemented by circuit backend ", __PACKAGE__);
}

# This method should be implemented by the backend child
# It will be called to request the teardown of a circuit
sub backendTeardownCircuit {
    my $self = shift;
    $self->Fatal("teardown not implemented by circuit backend ", __PACKAGE__);
}

# This method should be implemented by the backend child
# It will be called update the bandwidth
sub backendUpdateBandwidth {
    my $self = shift;
    $self->Fatal("request not implemented by backend ", __PACKAGE__);
}

1;