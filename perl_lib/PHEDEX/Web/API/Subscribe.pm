package PHEDEX::Web::API::Subscribe;
use warnings;
use strict;
use PHEDEX::Core::XML;
use PHEDEX::RequestAllocator::Core;
use PHEDEX::Web::Util;

=pod

=head1 NAME

PHEDEX::Web::API::Subscribe - make and approve a subscription request

=head2 subscribe

Subscribe data

=head3 options

 node		destination node names, can be multible
 level          subscription level, either 'dataset' or 'block'.  Default is
                'dataset'
 data		XML structure representing the data to be subscribed. See
		PHEDEX::Core::XML

=head3 return value

returns a hash with keys for the data, the node, the node-id, and the injection
statistics. The statistics is also a hash, with keys for:

 new datasets		number of new datasets created
 new blocks		number of new blocks created
 new files		number of new files created
 closed datasets	number of closed datasets injected
 closed blocks		number of closed blocks injected

If 'nostrict' is specified, attempting to re-insert already-inserted data will
not give an error, but all the stats values will be zero.

=cut

sub invoke { return inject(@_); }
sub inject
{
  my ($core,%args) = @_;
  &checkRequired(\%args, qw(node priority is_move is_static));

  $core->{SECMOD}->reqAuthnCert();
  my $auth = $core->getAuth();
  if (! $auth->{STATE} eq 'cert' ) {
      die("Certificate authentication failed\n");
  }

  my $nodes = [ arrayref_expand($args{node}) ];  
  foreach my $node (@$nodes) {
      my $nodeid = $auth->{NODES}->{$node} || 0;
      die("You are not authorised to subscribe data to node $node") unless $nodeid;
  }

  my $data = PHEDEX::Core::XML::parseData( XML => $args{data} );

  my $requests;
  eval
  {
      my $id_params = &PHEDEX::Core::Identity::getIdentityFromSecMod( $core, $core->{SECMOD} );
      my $identity = &PHEDEX::Core::Identity::fetchAndSyncIdentity( $core,
								    AUTH_METHOD => 'CERTIFICATE',
								    %$id_params );
      my $client_id = &PHEDEX::Core::Identity::logClientInfo($self,
							     $identity->{ID},
							     "Remote host" => $core->{REMOTE_HOST},
							     "User agent"  => $core->{USER_AGENT} );

      my $req_ids = &PHEDEX::RequestAllocator::Core::createRequest ($core, $data, $nodes,
								    TYPE => 'xfer',
								    LEVEL => $args{level} || 'DATASET',
								    TYPE_ATTR => { PRIORITY => $args{PRIORITY},
										   IS_MOVE => $args{IS_MOVE},
										   IS_STATIC => $args{IS_STATIC},
										   IS_TRANSIENT => 'n',
										   IS_DISTRIBUTED => 'n' },
								    COMMENTS => $args{COMMENTS},
								    CLIENT_ID => $client_id
								    );

      my $requests = &PHEDEX::RequestAllocator::Core::getTransferRequests($self, REQUESTS => $req_ids);
      foreach my $request (values %$requests) {
	  my $rid = $request->{ID};
	  foreach my $node (values %{$request->{NODES}}) {
	      # Check if user is authorized for this node
	      if (! $auth->{NODES}->{ $node->{NODE_ID} }) {
		  die "You are not authorised to subscribe data to node $node->{NAME}\n";
	      }
	      # Set the decision
	      &PHEDEX::RequestAllocator::Core::setRequestDecision($self, $rid, 
								  $node->{NODE_ID}, 'y', $client_id, $now);
	      
	      # Add the subscriptions (or update the move source)
	      if ($node->{POINT} eq 'd') {
		  &PHEDEX::RequestAllocator::Core::addSubscriptionsForRequest($self, $rid, $node->{NODE_ID}, $now);
	      } elsif ($node->{POINT} eq 's') {
		  &PHEDEX::RequestAllocator::Core::updateMoveSubscriptionsForRequest($self, $rid, 
										     $node->{NODE_ID}, $now);
	      }
	}
    }
}


  };
  if ( $@ )
  {
    $core->DBH->rollback; # Processes seem to hang without this!
    die $@;
  }
  $core->DBH->commit() if $stats;

  return {
	   Subscribe =>
	   {
	     data   => $args{data},
	     node   => $args{node},
	     requests  => $requests,
	   }
	 };
}

1;
