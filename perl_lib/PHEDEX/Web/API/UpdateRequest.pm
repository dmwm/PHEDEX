package PHEDEX::Web::API::UpdateRequest;
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

PHEDEX::Web::API::UpdateRequest - approve or dissaprove an already-existing transfer request

=head1 DESCRIPTION

Approve or dissaprove an already-existing transfer request

=head2 Options

 decision	'approve' or 'disapprove'. No default.
 request	Request-ID to act on
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

  &checkRequired(\%args, qw(request node decision));

  # check values of options
  die "unknown decision, allowed values are 'approve' or 'disapprove'" 
    unless $args{decision} =~ m%^(approve|disapprove)$%;
  $args{uc($args{decision})} = 1;

  die "Request-ID not numeric" unless $args{request} =~ m%^\d+$%;

  # check authentication
  $core->{SECMOD}->reqAuthnCert();
  my $auth;
  my %h;
# TW allow code to work from website or from data-service
# This is ugly...
  if ( $core->can('getAuth') ) {
    $auth = $core->getAuth('datasvc_subscribe');
  } else {
    my $secmod = $core->{SECMOD};
    $auth = {
        STATE  => $secmod->getAuthnState(),
        ROLES  => $secmod->getRoles(),
        DN     => $secmod->getDN(),
    };
    %h = $core->fetch_nodes(web_user_auth => 'Data Manager', with_ids => 1);
    $auth->{NODES} = \%h;

    my $nodes = [ arrayref_expand($args{node}) ];
    my (@rh,$nname);
    foreach my $nid ( @{$nodes} ) {
      $nname = "node_id $nid";
      foreach my $x ( keys %h ) {
        if ( $h{$x} == $nid ) {
          $nname = $x;
          last;
        }
      }
      push @rh, $nname;
    }
    $args{node} = \@rh;
  }
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
  my ($requests,$id_params,$identity,$client_id,);
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

  my ($sql, %p, $type);
  $type = PHEDEX::Core::DB::dbexec($core->{DBH}, qq{ select type from t_req_request where id = :id }, ':id' => $args{request} )->fetchrow();
  if    ( $type == 1  ) { $type = 'xfer'; }
  elsif ( $type == 2  ) { $type = 'delete'; }
  elsif ( $type == '' ) { die("Unknown request: $args{request}"); }
  else { die("Unknown request type: '$type'\n"); }


  my $now = time();
  eval {
    if ( $type eq 'xfer' ) {
      $requests = &PHEDEX::RequestAllocator::Core::getTransferRequests($core, REQUESTS => [$args{request}]);
    } elsif ( $type eq 'delete' ) {
      $requests = &PHEDEX::RequestAllocator::Core::getDeleteRequests($core, REQUESTS => [$args{request}]);
    }
  };
  die("Couldn't retrieve request $args{request}") if $@;

  my ($selected_requests,$request,$rid,%node_count,$extra_nodes);
# Verify authorisation first...
  foreach $request (values %$requests) {
    $selected_requests = {};
    foreach my $node_id (keys %{$request->{NODES}}) {
      my $node  = $request->{NODES}{$node_id};
      next unless grep(/^$node->{NODE}$/,@{$nodes}); # Check if this node is required
       $node_count{$node->{NODE}}++;
      # Check if user is authorized for this node
      if (! $auth->{NODES}->{ $node->{NODE} }) {
	die "You are not authorised to approve data to node $node->{NODE}\n";
      }
      $selected_requests->{$node_id} = $node;
    }
    $request->{NODES} = {};
    foreach ( keys %{$selected_requests} ) { $request->{NODES}{$_} = $selected_requests->{$_}; }
  }

  $extra_nodes = '';
  foreach ( sort @{$nodes} ) {
    if ( !$node_count{$_} ) {
      if ( $extra_nodes ) { $extra_nodes .= ', '; }
      $extra_nodes .= $_;
    }
  }
  if ( $extra_nodes ) {
    die("Request ID=$args{request} does not include node(s) $extra_nodes");
  }
# Set the request decision
  foreach $request (values %$requests) {
    $rid = $request->{ID};
    my $decision = 'maybe';
    if ( $args{APPROVE}    ) { $decision = 'y' }
    if ( $args{DISAPPROVE} ) { $decision = 'n' }
    foreach my $node (values %{$request->{NODES}}) {
      eval {
        &PHEDEX::RequestAllocator::Core::setRequestDecision($core, $rid, $node->{NODE_ID}, $decision, $client_id, $now);
      };
      if ( $@ ) {
        if ( $@ =~ m%ORA-00001: unique constraint% ) { die "Request $rid has already been decided at node $node->{NODE}"; }
        die $@;
      }
    }
  }

  my ($ds_ids,$b_ids,$data,$groupMap);
  $groupMap = PHEDEX::Core::SQL::getGroupMap($core);
  eval {
#   Now act on different request types
    foreach $request (values %$requests) {
      $rid = $request->{ID};
      foreach my $node (values %{$request->{NODES}}) {
        if ( $args{APPROVE} ) {
          if ( $request->{TYPE} eq 'xfer' ) {

            ($ds_ids,$b_ids) = PHEDEX::RequestAllocator::Core::getExistingRequestData( $core, $rid,
				  EXPAND_DATASETS => ($request->{IS_STATIC} eq 'y' ? 1 : 0)
				);
            $data = {
		FORMAT		=> 'existingrequestdata',
		DBS		=> $request->{DBS},
		DBS_ID		=> $request->{DBS_ID},
		DATA		=> $request->{DATA},
		DATASET_IDS	=> $ds_ids,
		BLOCK_IDS	=> $b_ids,
	    };
            # Re-validate the subscriptions, because of https://savannah.cern.ch/bugs/?79121
            my @validate_args = (
				DATA => $data,
			 	TYPE => 'xfer',
				LEVEL => $request->{level},
				PRIORITY => $request->{PRIORITY},
				IS_MOVE => $request->{IS_MOVE},
				IS_STATIC => $request->{IS_STATIC},
				IS_CUSTODIAL => $request->{IS_CUSTODIAL},
				USER_GROUP => $groupMap->{$request->{USER_GROUP}},
				TIME_START => $request->{TIME_START},
				IS_TRANSIENT => 'n',
				IS_DISTRIBUTED => 'n',
				COMMENTS => 'no comment...',
				CLIENT_ID => $client_id,
				INSTANCE => $core->{INSTANCE},
				NOW => $now
				);

            eval {
              my @valid_args = &PHEDEX::RequestAllocator::Core::validateRequest(
				$core, $data, [$node->{NODE}],
			 	@validate_args
				);
            };
            die $@ if $@;

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
            }

            if ( $request->{IS_MOVE} eq 'y' ) {
	      if ($node->{POINT} eq 's') {
	        # Remove the subcriptions for the move source
	        &PHEDEX::RequestAllocator::Core::deleteSubscriptionsForRequest($core, $rid, $node->{NODE_ID}, $now);
	      }
            }
          } elsif ( $request->{TYPE} eq 'delete' ) {
	    &PHEDEX::RequestAllocator::Core::deleteSubscriptionsForRequest($core, $rid, $node->{NODE_ID}, $now);
	    &PHEDEX::RequestAllocator::Core::addDeletionsForRequest($core, $rid, $node->{NODE_ID}, $now);
          } else {
            # This is impossible because of the checks above, but anyway...
            die("Request $rid: TYPE is neither 'xfer' nor 'delete' ($request->{TYPE})");
          }
        } elsif ( $args{DISAPPROVE} ) {
          # nothing to do, the request decision has already been set
        } else {
          die("Decision is neither approve nor disapprove, somebody has a bug!");
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
