package PHEDEX::Web::API::Approve;
use warnings;
use strict;

use PHEDEX::Core::XML;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Util qw( arrayref_expand );
use PHEDEX::Core::Identity;
use PHEDEX::RequestAllocator::Core;
use PHEDEX::Web::Util;
use PHEDEX::Core::Mail;
use URI::Escape;

=pod

=head1 NAME

PHEDEX::Web::API::Approve - approve, dissaprove, or append a comment to an already-existing transfer request

=head1 DESCRIPTION

Approve, dissaprove, or append a comment to an already-existing transfer request

=head2 Options

 action		'approve', 'disapprove', or 'none'. No default.
 rid		Request-ID to act on
 node		destination node names, can be multiple
 comments	other information to attach to this request, for whatever reason.

=head2 Input

=head3 Output

If successful returns a 'request_updated' element with one attribute,
'id', which is the request ID.

=cut

sub duration { return 0; }
sub need_auth { return 1; }
sub methods_allowed { return 'POST'; }
sub invoke { return approve(@_); }
sub approve
{
  my ($core, %args) = @_;

  &checkRequired(\%args, qw(rid node action));

  # check values of options
  die "unknown action, allowed values are 'approve', 'disapprove' or 'none'" 
    unless $args{action} =~ m%^(approve|disapprove|none)$%;
  $args{uc($args{action})} = 1;

  die "Request-ID not numeric" unless $args{rid} =~ m%^\d+$%;

  # check authentication
  $core->{SECMOD}->reqAuthnCert();
  my $auth = $core->getAuth('datasvc_subscribe');
  if (! $auth->{STATE} eq 'cert' ) {
    die("Certificate authentication failed\n");
  }

  # check authorization
  my $nodes = [ arrayref_expand($args{node}) ];
  foreach my $node (@{$nodes}) {
    my $nodeid = $auth->{NODES}->{$node} || 0;
    die("You are not authorised to approve data to node $node") unless $nodeid;
  }

  # ok, now try to act on the request
  my ($requests,$id_params,$identity,$client_id);
  eval
  {
    $id_params = &PHEDEX::Core::Identity::getIdentityFromSecMod( $core, $core->{SECMOD} );
    $identity = &PHEDEX::Core::Identity::fetchAndSyncIdentity( $core,
							       AUTH_METHOD => 'CERTIFICATE',
							       %$id_params );
    $client_id = &PHEDEX::Core::Identity::logClientInfo($core,
						        $identity->{ID},
						        "Remote host" => $core->{REMOTE_HOST},
						        "User agent"  => $core->{USER_AGENT} );
  };
  die "Error evaluating client identity" if $@;

  eval {
    my $rid = $args{rid};
    my $now = time();
    $requests = &PHEDEX::RequestAllocator::Core::getTransferRequests($core, REQUESTS => [$rid]);
    foreach my $request (values %$requests) {
      $rid = $request->{ID};
      if ( $args{APPROVE} ) {
        foreach my $node (values %{$request->{NODES}}) {
	  # Check if this node is required
	  next unless grep(/^$node->{NODE}$/,@{$nodes});

          # Check if user is authorized for this node
	  if (! $auth->{NODES}->{ $node->{NODE} }) {
	    die "You are not authorised to approve data to node $node->{NODE}\n";
	  }
 
	  # Set the decision
          eval {
	  &PHEDEX::RequestAllocator::Core::setRequestDecision($core, $rid, 
							      $node->{NODE_ID}, 'y', $client_id, $now);
          };
          if ( $@ ) {
            if ( $@ =~ m%ORA-00001: unique constraint% ) { die "Request has already been decided"; }
            die $@;
          }
	  # Add the subscriptions
	  if ($node->{POINT} eq 'd') {
	    # Add the subscription parameter set (or retrieve it if existing)
	    my $paramid;
	    $paramid = &PHEDEX::RequestAllocator::Core::createSubscriptionParam($core,
									        REQUEST => $rid,
									        PRIORITY => $request->{PRIORITY},
									        IS_CUSTODIAL => $request->{IS_CUSTODIAL},
									        USER_GROUP => $request->{USER_GROUP},
									        ORIGINAL => 1,
									        TIME_CREATE => $now
									       );
	    &PHEDEX::RequestAllocator::Core::addSubscriptionsForParamSet($core, $paramid, $node->{NODE_ID}, $now);
	  } elsif ($node->{POINT} eq 's') {
	    # Remove the subcriptions for the move source
	    &PHEDEX::RequestAllocator::Core::deleteSubscriptionsForRequest($core, $rid, 
									   $node->{NODE_ID}, $now);
	  }
        }
      }
    }
  };
  if ( $@ )
  {
    $core->{DBH}->rollback(); # Processes seem to hang without this!
    die $@;
  }

  # determine if we commit
  my $commit = 0;
  if (%$requests) {
    $commit = 1;
  } else {
    die "no requests were created\n";
    $core->{DBH}->rollback();
  }
  $commit = 0 if $args{dummy};
  $commit ? $core->{DBH}->commit() : $core->{DBH}->rollback();
 
  # for output, we return a list of the generated request IDs
  my @req_ids = map { { id => $_ } } keys %$requests;
  push @req_ids, { args => \%args };
  return { request_updated  => \@req_ids };
}

1;
