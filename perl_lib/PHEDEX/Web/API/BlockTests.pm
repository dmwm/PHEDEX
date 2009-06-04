package PHEDEX::Web::API::BlockTests;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::BolckTests -- consistency-check results

=head1 DESCRIPTION

Show consistency-check results

=head2 Options

 required inputs: none
 optional inputs: (as filters) node, block, test, status, test_since

 node             node name, could be multiple
 block            block name, could be multiple
 kind             "cksum", "size", "dbs", or "migration"
                  default is to show any
 status           "OK", "Fail", "Queued", "Active", "Timeout", "Expired",
                  "Suspended", "Error", "Rejected" or "Indeterminate"
                  default is to show any
 test_since       show only tests after this time (*)

 (*) if no option is specified, test_since is set to 24 hours ago

=head2 Output

 <node>
   <block>
     <test/>
     ...
   </block>
   ...
 </node>

=head3 <node> elements

 id              node id
 name            node name
 se              storage element

=head3 <block> elements

 id              block id
 name            block name
 files           files in block
 bytes           bytes in block

=head3 <test> elements

 id              test request id
 kind            type of test, one of the followings:
                 "cksum", "size", "dbs", or "migration"
 time_reported   the time when the test was done
 status          status of the test one of the followings:
                 "OK", "Fail", "Queued", "Active", "Timeout", "Expired",
                 "Suspended", "Error", "Rejected" or "Indeterminate"
 files           number of files tested
 files_ok        number of files tested OK

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;

my $map = {
    _KEY => 'NODE',
    node => 'NODE',
    id => 'NODEID',
    se => 'SE',
    block => {
        _KEY => 'BLOCKID',
        id => 'BLOCKID',
        name => 'BLOCK',
        files => 'FILES',
        bytes => 'BYTES',
        test => {
            _KEY => 'ID',
            id => 'ID',
            kind => 'KIND',
            time_reported => 'TIME_REPORTED',
            status => 'STATUS',
            files => 'N_FILES',
            files_tested => 'N_TESTED',
            files_ok => 'N_OK',
        }
    }
};

sub duration { return 60 * 60; }
sub invoke { return blocktests(@_); }

sub blocktests
{
    my ($core, %h) = @_;

    # convert parameter keys to upper case
    foreach ( qw / node block kind status test_since test / )
    {
      $h{uc $_} = delete $h{$_} if $h{$_};
    }

    # if there is no argument, set default test_since to 24 hours ago
    if (scalar keys %h == 0)
    {
        $h{TEST_SINCE} = time() - 3600*24;
    }

    $h{'#DETAILED#'} = 0; # no file info at all

    # remember to handle the case for status
    return { node => PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getBlockTestFiles($core, %h)) };
}

1;
