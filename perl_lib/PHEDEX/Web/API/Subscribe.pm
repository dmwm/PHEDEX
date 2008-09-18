package PHEDEX::Web::API::Subscribe;

use warnings;
use strict;

use PHEDEX::Core::XML;
use PHEDEX::Core::Timing;
use PHEDEX::Core::Util qw( arrayref_expand );
use PHEDEX::Core::Identity;
use PHEDEX::RequestAllocator::Core;
use PHEDEX::Web::Util;

=pod

=head1 NAME

PHEDEX::Web::API::Subscribe - make and approve a subscription request

=head2 subscribe

Subscribe data

=head3 options

 node		destination node names, can be multible
 data		XML structure representing the data to be subscribed. See
		PHEDEX::Core::XML
 level          subscription level, either 'dataset' or 'block'.  Default is
                'dataset'
 priority       subscription priority, either 'high', 'normal', or 'low'. Default is 'low'
 move           'y' or 'n', for 'move' or 'replica' subscription.  Default is 'n' (replica)
 static         'y' or 'n', for 'static' or 'growing' subscription.  Default is 'n' (static)

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
    my ($core, %args) = @_;
    &checkRequired(\%args, qw(data node));
    # default values for options
    $args{priority} ||= 'low';
    $args{move} ||= 'n';
    $args{static} ||= 'n';
    $args{level} ||= 'DATASET'; $args{level} = uc $args{level};

    # check values of options
    my %priomap = ('high' => 0, 'normal' => 1, 'low' => 2);
    die "unknown priority, allowed values are 'high', 'normal' or 'low'" 
	unless exists $priomap{$args{priority}};
    $args{priority} = $priomap{$args{priority}}; # translate into numerical value

    foreach (qw(move static)) {
	die "'$_' must be 'y' or 'n'" unless $args{$_} =~ /^[yn]$/;
    }

    unless (grep $args{level} eq $_, qw(DATASET BLOCK)) {
	die "'level' must be either 'dataset' or 'block'";
    }

    # check authentication
    $core->{SECMOD}->reqAuthnCert();
    my $auth = $core->getAuth();
    if (! $auth->{STATE} eq 'cert' ) {
	die("Certificate authentication failed\n");
    }

    # check authorization
    my $nodes = [ arrayref_expand($args{node}) ];  
    foreach my $node (@$nodes) {
	my $nodeid = $auth->{NODES}->{$node} || 0;
	die("You are not authorised to subscribe data to node $node") unless $nodeid;
    }

    # ok, now try to make the request and subscribe it
    my $now = &mytimeofday();
    my $data = PHEDEX::Core::XML::parseData( XML => $args{data} );

    my $requests;
    eval
    {
	my $id_params = &PHEDEX::Core::Identity::getIdentityFromSecMod( $core, $core->{SECMOD} );
	my $identity = &PHEDEX::Core::Identity::fetchAndSyncIdentity( $core,
								      AUTH_METHOD => 'CERTIFICATE',
								      %$id_params );
	my $client_id = &PHEDEX::Core::Identity::logClientInfo($core,
							       $identity->{ID},
							       "Remote host" => $core->{REMOTE_HOST},
							       "User agent"  => $core->{USER_AGENT} );

	my @req_ids = &PHEDEX::RequestAllocator::Core::createRequest ($core, $data, $nodes,
								      TYPE => 'xfer',
								      LEVEL => $args{level},
								      TYPE_ATTR => { PRIORITY => $args{priority},
										     IS_MOVE => $args{move},
										     IS_STATIC => $args{static},
										     IS_TRANSIENT => 'n',
										     IS_DISTRIBUTED => 'n' },
								      COMMENTS => $args{COMMENTS},
								      CLIENT_ID => $client_id,
								      NOW => $now
								      );

	$requests = &PHEDEX::RequestAllocator::Core::getTransferRequests($core, REQUESTS => \@req_ids);
	foreach my $request (values %$requests) {
	    my $rid = $request->{ID};
	    foreach my $node (values %{$request->{NODES}}) {
		# Check if user is authorized for this node
		if (! $auth->{NODES}->{ $node->{NODE} }) {
		    die "You are not authorised to subscribe data to node $node->{NODE}\n";
		}
		# Set the decision
		&PHEDEX::RequestAllocator::Core::setRequestDecision($core, $rid, 
								    $node->{NODE_ID}, 'y', $client_id, $now);
		
		# Add the subscriptions (or update the move source)
		if ($node->{POINT} eq 'd') {
		    &PHEDEX::RequestAllocator::Core::addSubscriptionsForRequest($core, $rid, $node->{NODE_ID}, $now);
		} elsif ($node->{POINT} eq 's') {
		    &PHEDEX::RequestAllocator::Core::updateMoveSubscriptionsForRequest($core, $rid, 
										       $node->{NODE_ID}, $now);
		}
	    }
	}
    };
    if ( $@ )
    {
	$core->DBH->rollback(); # Processes seem to hang without this!
	die $@;
    }
    if (%$requests) {
	$core->DBH->commit();
    } else {
	$core->DBH->rollback();
	die "no requests were created";
    }
    
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
