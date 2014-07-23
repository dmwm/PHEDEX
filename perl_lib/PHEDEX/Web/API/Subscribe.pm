package PHEDEX::Web::API::Subscribe;
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

PHEDEX::Web::API::Subscribe - create transfer requests and approve them to make data subscriptions

=head1 DESCRIPTION

Makes and approves a transfer request, creating data subscriptions.

=head2 Options

 node		destination node names, can be multiple
 data		XML structure representing the data to be subscribed. See
		PHEDEX::Core::XML
 level          subscription level, either 'dataset' or 'block'.  Default is
                'dataset'
 priority       subscription priority, either 'high', 'normal', or 'low'. Default is 'low'
 move           'y' or 'n', for 'move' or 'replica' subscription.  Default is 'n' (replica)
 static         'y' or 'n', for 'static' or 'growing' subscription.  Default is 'n' (growing)
 custodial      'y' or 'n', whether the subscriptions are custodial.  Default is 'n' (non-custodial)
 group          group the request is for.  Default is undefined.
 time_start     starting time for dataset-level request. Default is undefined (all blocks in dataset)
 request_only   'y' or 'n', if 'y' then create the request but do not approve.  Default is 'n'.
 no_mail        'y' or 'n' (default), if 'n', a email is sent to
                requestor, datamanagers, site admins, and global admins
 comments	other information to attach to this request, for whatever
		reason.

=head2 Input

This API call takes POST'ed XML in the same format as the 'Inject' API, check the documentation there for details.

=head3 Output

If successful returns a 'request_created' element with one attribute,
'id', which is the request ID.

=cut

sub duration { return 0; }
sub need_auth { return 1; }
sub methods_allowed { return 'POST'; }
sub invoke { return subscribe(@_); }
sub subscribe
{
    my ($core, %args) = @_;

    $args{priority} ||= 'low';
    $args{move} ||= 'n';
    $args{static} ||= 'n';
    $args{custodial} ||= 'n';
    $args{request_only} ||= 'n';
    $args{level} ||= 'DATASET'; $args{level} = uc $args{level};
    $args{no_mail} ||= 'n';

    # validation only, no to-upper
    my %p;
    eval
    {
        %p = &validate_params(\%args,
                allow => [ qw ( node data level priority move static custodial group time_start request_only no_mail comments ) ],
                required => [ qw ( data node group ) ],
                spec =>
                {
                    node => { using => 'node', multiple => 1 },
                    data => { using => 'xml' },
                    level => { regex => qr/^BLOCK$|^DATASET$/ },
                    priority => { using => 'priority', multiple => 1 },
                    move => { using => 'yesno' },
                    static => { using => 'yesno' },
                    custodial => { using => 'yesno' },
                    group => { using => 'text' },
                    time_start => { using => 'time' },
                    request_only => { using => 'yesno' },
                    no_mail => { using => 'yesno' },
                    comments => { using => 'text' },
                    dummy => { using => 'text' },
                    're-evaluate' => { using => 'yesno' },
                }
        );
    };
    if ($@)
    {
        die PHEDEX::Web::Util::http_error(400,$@);
    }
                
    die PHEDEX::Web::Util::http_error(400,"group $args{group} is forbidden") if ($args{group} =~ m/^deprecated-/);
    # default values for options
    # check values of options
    my %priomap = ('high' => 0, 'normal' => 1, 'low' => 2);
    die PHEDEX::Web::Util::http_error(400,"unknown priority, allowed values are 'high', 'normal' or 'low'") 
	unless exists $priomap{$args{priority}};
    $args{priority} = $priomap{$args{priority}}; # translate into numerical value

    # check authentication
    if ( ! ($core->{SECMOD}->isSecure() &&
            $core->{SECMOD}->isAuthenticated() ) )
    {
      die PHEDEX::Web::Util::http_error(401,"You must be authenticated to access this API");
    }
    my ($auth,$auth_method);
    if ( $core->{SECMOD}->isCertAuthenticated() ) { $auth_method = 'CERTIFICATE'; }
    if ( $core->{SECMOD}->isPasswdAuthenticated() ) { $auth_method = 'PASSWORD'; }
    if ( $args{request_only} eq 'n' ) {
      $auth = $core->getAuth('datasvc_subscribe');
      if ( $auth_method ne 'CERTIFICATE' ) {
        die PHEDEX::Web::Util::http_error(401,"You must be authenticated with a certificate to auto-approve requests");
      }
    } else {
      $auth = $core->getAuth();
    }
    # ok, now try to make the request and subscribe it
    my $nodes = [ arrayref_expand($args{node}) ];  
    my $now = &mytimeofday();
    my $data = uri_unescape($args{data});
    $args{comments} = uri_unescape($args{comments});
    $data = PHEDEX::Core::XML::parseData( XML => $data);
    # only one DBS allowed for the moment...  (FIXME??)
    die PHEDEX::Web::Util::http_error(400,"multiple DBSes in data XML.  Only data from one DBS may be subscribed at a time")
	if scalar values %{$data->{DBS}} > 1;
    ($data) = values %{$data->{DBS}};
    $data->{FORMAT} = 'tree';

    my $requests;
    my $rid2;
    eval
    {
	my ($rid,@valid_args,$client_id,$identity,$id_params);
	$id_params = &PHEDEX::Core::Identity::getIdentityFromSecMod( $core, $core->{SECMOD} );
	$identity = &PHEDEX::Core::Identity::fetchAndSyncIdentity( $core,
								   AUTH_METHOD => $auth_method,
								   %$id_params );
	$client_id = &PHEDEX::Core::Identity::logClientInfo($core,
							    $identity->{ID},
							    "Remote host" => $core->{REMOTE_HOST},
							    "User agent"  => $core->{USER_AGENT} );
   
	@valid_args = &PHEDEX::RequestAllocator::Core::validateRequest($core, $data, $nodes,
								       TYPE => 'xfer',
								       LEVEL => $args{level},
								       PRIORITY => $args{priority},
								       IS_MOVE => $args{move},
								       IS_STATIC => $args{static},
								       IS_CUSTODIAL => $args{custodial},
								       USER_GROUP => $args{group},
								       TIME_START => $args{time_start},
								       IS_TRANSIENT => 'n',
								       IS_DISTRIBUTED => 'n',
								       COMMENTS => $args{comments},
								       CLIENT_ID => $client_id,
								       INSTANCE => $core->{INSTANCE},
								       NOW => $now
								      );

	$rid = &PHEDEX::RequestAllocator::Core::createRequest($core, @valid_args);
        $rid2 = $rid;
	$requests = &PHEDEX::RequestAllocator::Core::getTransferRequests($core, REQUESTS => [$rid]);
	unless ($args{request_only} eq 'y') {
	    foreach my $request (values %$requests) {
		$rid = $request->{ID};
		foreach my $node (values %{$request->{NODES}}) {
		    # Check if user is authorized for this node
		    if (! $auth->{NODES}->{ $node->{NODE} }) {
			die PHEDEX::Web::Util::http_error(400,"You are not authorised to subscribe data to node $node->{NODE}");
		    }
		    # Set the decision
		    &PHEDEX::RequestAllocator::Core::setRequestDecision($core, $rid, 
									$node->{NODE_ID}, 'y', $client_id, $now);
		    
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
		    # Remove the subcriptions for the move source
		    } elsif ($node->{POINT} eq 's') {
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
	die PHEDEX::Web::Util::http_error(400,$@);
    }

    # determine if we commit
    my $commit = 0;
    if (%$requests) {
	$commit = 1;
    } else {
	die PHEDEX::Web::Util::http_error(400,"no requests were created");
	$core->{DBH}->rollback();
    }
    $commit = 0 if $args{dummy};
    $commit ? $core->{DBH}->commit() : $core->{DBH}->rollback();
    # send out notification
    if ($args{no_mail} eq 'n')
    {
      if ( $core->{CONFIG}{TESTING_MODE} ) {
        PHEDEX::Core::Mail::testing_mode('on');
        PHEDEX::Core::Mail::testing_mail($core->{CONFIG}{TESTING_MAIL});
      }
      PHEDEX::Core::Mail::send_request_create_email($core, $rid2) if $commit;
    }
    
    # for output, we return a list of the generated request IDs
    my @req_ids = map { { id => $_ } } keys %$requests;
    return { request_created  => \@req_ids };
}

1;
