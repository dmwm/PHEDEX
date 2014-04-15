package PHEDEX::Web::API::Delete;
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

PHEDEX::Web::API::Delete - generate deletion request

=head1 DESCRIPTION

Makes deletion requests

=head2 Options

 node             destination node name, can be multiple
 data             XML structure representing the data to be deleted. See PHEDEX::Core::XML
 level            deletion level, either 'dataset' or 'block'.  Default is 'dataset'
 rm_subscriptions 'y' or 'n', remove subscriptions, default is 'y'.
 comments         other information to attach to this request, for whatever reason.

=head2 Input

This API call takes POST'ed XML in the following format:

  <data version="2.0">
   <dbs name="https://cmsweb.cern.ch/dbs/prod/global/DBSReader">
     <dataset name="/sample/dataset" is-open="y" is-transient="n">
       <block name="/sample/dataset#1" is-open="y">
         <file name="file1" bytes="10" checksum="cksum:1234"/>
         <file name="file2" bytes="22" checksum="cksum:456"/>
       </block>
       <block name="/sample/dataset#2" is-open="y">
         <file name="file3" bytes="1" checksum="cksum:2"/>
       </block>
     </dataset>
     <dataset name="/sample/dataset2" is-open="n" is-transient="n">
       <block name="/sample/dataset2#1" is-open="n"/>
       <block name="/sample/dataset2#2" is-open="n"/>
     </dataset>
   </dbs>
  </data>

=head3 Output

If successful returns a 'request_created' element with one attribute,
'id', which is the request ID.

=cut

sub duration { return 0; }
sub need_auth { return 1; }
sub methods_allowed { return 'POST'; }
sub invoke { return to_delete(@_); }

sub to_delete
{
    my ($core, %h) = @_;

    # defaults
    $h{rm_subscriptions} ||= 'y';
    $h{level} ||= 'DATASET'; $h{level} = uc $h{level};

    # validation only, no to-upper
    my %p;
    eval
    {
        %p = &validate_params(\%h,
                allow => [ qw ( node data level rm_subscriptions comments ) ],
                required => [ qw (node data) ],
                spec =>
                {
                    node => { using => 'node', multiple => 1 },
                    data => { using => 'xml' },
                    level => { regex => qr/^BLOCK$|^DATASET$/ },
                    rm_subscriptions => { using => 'yesno' },
                    comments => { using => 'text' }
                }
        );
    };
    if ($@)
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }

    my $nodes = [ arrayref_expand($h{node}) ];
    # check authentication
    $core->{SECMOD}->reqAuthnCert();
    my $auth = $core->getAuth();
    delete $auth->{ROLES}->{Admin};
    if (! $auth->{STATE} eq 'cert' ) {
	die PHEDEX::Web::Util::http_error(401,"Certificate authentication failed");
    }

    my $now = &mytimeofday();
    my $data = uri_unescape($h{data}); 
    $h{comments} = uri_unescape($h{comments});
    $data = PHEDEX::Core::XML::parseData( XML => $data);

    # only one DBS allowed for the moment...  (FIXME??)
    die PHEDEX::Web::Util::http_error(400,"multiple DBSes in data XML.  Only data from one DBS may be deleted at a time")
	if scalar values %{$data->{DBS}} > 1;

    ($data) = values %{$data->{DBS}};
    $data->{FORMAT} = 'tree';

    my $requests;
    my $rid;

    eval
    {
        my $id_params = &PHEDEX::Core::Identity::getIdentityFromSecMod( $core, $core->{SECMOD} );
        my $identity = &PHEDEX::Core::Identity::fetchAndSyncIdentity( $core,
                                                                      AUTH_METHOD => 'CERTIFICATE',
                                                                      %$id_params );
        my $client_id = &PHEDEX::Core::Identity::logClientInfo( $core,
                                                                $identity->{ID},
                                                                "Remote host" => $core->{REMOTE_HOST},
                                                                "User agent"  => $core->{USER_AGENT} );

        my @valid_args = &PHEDEX::RequestAllocator::Core::validateRequest($core, $data, $nodes,
                                                                          TYPE => 'delete',
									  LEVEL => $h{level},
                                                                          RM_SUBSCRIPTIONS => $h{rm_subscriptions},
									  COMMENTS => $h{comments},
									  CLIENT_ID => $client_id,
									  INSTANCE => $core->{INSTANCE},
									  NOW => $now
									  );

        $rid = &PHEDEX::RequestAllocator::Core::createRequest($core, @valid_args);
    };

    if ($@)
    {
        $core->{DBH}->rollback(); # Processes seem to hang without this!
        die PHEDEX::Web::Util::http_error(400,$@);
    }

    $core->{DBH}->commit(); # Could be over committed, but who cares?
    # send out notification
    PHEDEX::Core::Mail::testing_mail($core->{CONFIG}{TESTING_MAIL});
    PHEDEX::Core::Mail::send_request_create_email($core, $rid);

    return { request_created  => [ { id => $rid } ] };
}

1;
