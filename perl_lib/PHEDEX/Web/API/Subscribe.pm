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

PHEDEX::Web::API::Subscribe - create transfer requests and approve them to make data subscriptions

=head1 DESCRIPTION

Makes and approves a transfer request, creating data subscriptions.

=head2 Options

 node		destination node names, can be multible
 data		XML structure representing the data to be subscribed. See
		PHEDEX::Core::XML
 level          subscription level, either 'dataset' or 'block'.  Default is
                'dataset'
 priority       subscription priority, either 'high', 'normal', or 'low'. Default is 'low'
 move           'y' or 'n', for 'move' or 'replica' subscription.  Default is 'n' (replica)
 static         'y' or 'n', for 'static' or 'growing' subscription.  Default is 'n' (static)
 custodial      'y' or 'n', whether the subscriptions are custodial.  Default is 'n' (non-custodial)
 group          group the request is for.  Default is undefined.
 request_only   'y' or 'n', if 'y' then create the request but do not approve.  Default is 'n'.

=head2 Input

This API call takes POST'ed XML in the following format:

   <dbs name="http://cmsdoc.cern.ch/cms/aprom/DBS/CGIServer/query">
     <dataset name="/sample/dataset" is-open="y" is-transient="n">
       <block name="/sample/dataset#1" is-open="y">
         <file lfn="file1" size="10" checksum="cksum:1234"/>
         <file lfn="file2" size="22" checksum="cksum:456"/>
       </block>
       <block name="/sample/dataset#2" is-open="y">
         <file lfn="file3" size="1" checksum="cksum:2"/>
       </block>
     </dataset>
     <dataset name="/sample/dataset2" is-open="n" is-transient="n">
       <block name="/sample/dataset2#1" is-open="n"/>
       <block name="/sample/dataset2#2" is-open="n"/>
     </dataset>
   </dbs>

=head3 Output

If successful returns a 'request_created' element with one attribute,
'id', which is the request ID.

=cut

sub duration { return 0; }
sub need_auth { return 1; }
sub invoke { return subscribe(@_); }
sub subscribe
{
    my ($core, %args) = @_;
    &checkRequired(\%args, qw(data node));
    # default values for options
    $args{priority} ||= 'low';
    $args{move} ||= 'n';
    $args{static} ||= 'n';
    $args{custodial} ||= 'n';
    $args{request_only} ||= 'n';
    $args{level} ||= 'DATASET'; $args{level} = uc $args{level};

    # check values of options
    my %priomap = ('high' => 0, 'normal' => 1, 'low' => 2);
    die "unknown priority, allowed values are 'high', 'normal' or 'low'" 
	unless exists $priomap{$args{priority}};
    $args{priority} = $priomap{$args{priority}}; # translate into numerical value

    foreach (qw(move static custodial request_only)) {
	die "'$_' must be 'y' or 'n'" unless $args{$_} =~ /^[yn]$/;
    }

    unless (grep $args{level} eq $_, qw(DATASET BLOCK)) {
	die "'level' must be either 'dataset' or 'block'";
    }

    # check authentication
    $core->{SECMOD}->reqAuthnCert();
    my $auth = $core->getAuth('datasvc_subscribe');
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
    # only one DBS allowed for the moment...  (FIXME??)
    die "multiple DBSes in data XML.  Only data from one DBS may be subscribed at a time\n"
	if scalar values %{$data->{DBS}} > 1;
    ($data) = values %{$data->{DBS}};
    $data->{FORMAT} = 'tree';

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
   
	my @valid_args = &PHEDEX::RequestAllocator::Core::validateRequest($core, $data, $nodes,
									  TYPE => 'xfer',
									  LEVEL => $args{level},
									  PRIORITY => $args{priority},
									  IS_MOVE => $args{move},
									  IS_STATIC => $args{static},
									  IS_CUSTODIAL => $args{custodial},
									  USER_GROUP => $args{group},
									  IS_TRANSIENT => 'n',
									  IS_DISTRIBUTED => 'n',
									  COMMENTS => $args{comments},
									  CLIENT_ID => $client_id,
									  NOW => $now
									  );

	my $rid = &PHEDEX::RequestAllocator::Core::createRequest($core, @valid_args);
	$requests = &PHEDEX::RequestAllocator::Core::getTransferRequests($core, REQUESTS => [$rid]);
	unless ($args{request_only} eq 'y') {
	    foreach my $request (values %$requests) {
		$rid = $request->{ID};
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
    return { request_created  => \@req_ids };
}

1;
