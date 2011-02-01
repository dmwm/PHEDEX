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
use Data::Dumper;

=pod

=head1 NAME

PHEDEX::Web::API::Delete - generate deletion request

=head1 DESCRIPTION

Makes deletion requests

=head2 Options

 node             destination node name, can be multible
 data             XML structure representing the data to be subscribed. See PHEDEX::Core::XML
 level            subscription level, either 'dataset' or 'block'.  Default is 'dataset'
 rm_subscriptions 'y' or 'n', remove subscriptions, default is 'y'.
 no_mail          'y' or 'n' (default), if 'n', a email is sent to requestor, datamanagers, site admins, and global admins

=head2 Input

This API call takes POST'ed XML in the following format:

   <dbs name="http://cmsdoc.cern.ch/cms/aprom/DBS/CGIServer/query">
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
    &checkRequired(\%h, qw(data node));
    # defaults
    $h{rm_subscriptions} ||= 'y';
    $h{level} ||= 'DATASET'; $h{level} = uc $h{level};
    foreach (qw(rm_subscriptions)) {
	die "'$_' must be 'y' or 'n'" unless $h{$_} =~ /^[yn]$/;
    }
    unless (grep $h{level} eq $_, qw(DATASET BLOCK)) {
	die "'level' must be either 'dataset' or 'block'";
    }

    # check authentication
    $core->{SECMOD}->reqAuthnCert();
    my $auth = $core->getAuth('datasvc_inject');
    if (! $auth->{STATE} eq 'cert' ) {
	die("Certificate authentication failed\n");
    }

    # check authorization
    my $nodes = [ arrayref_expand($h{node}) ];  
    foreach my $node (@$nodes) {
	my $nodeid = $auth->{NODES}->{$node} || 0;
	die("You are not authorised to delete data from node $node") unless $nodeid;
    }

    my $now = &mytimeofday();
    my $data = uri_unescape($h{data}); 
    $data = PHEDEX::Core::XML::parseData( XML => $data);

    # only one DBS allowed for the moment...  (FIXME??)
    die "multiple DBSes in data XML.  Only data from one DBS may be subscribed at a time\n"
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
									  CLIENT_ID => $client_id,
									  INSTANCE => $core->{INSTANCE},
									  NOW => $now
									  );

        $rid = &PHEDEX::RequestAllocator::Core::createRequest($core, @valid_args);
    };

    if ($@)
    {
        $core->{DBH}->rollback(); # Processes seem to hang without this!
        die $@;
    }

    $core->{DBH}->commit(); # Could be over committed, but who cares?

    return { request_created  => [ { id => $rid } ] };
}

1;
