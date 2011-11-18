package PHEDEX::Web::API::BlockTestFiles;
use warnings;
use strict;

=pod

=head1 NAME

PHEDEX::Web::API::BlockTestFiles -- detailed consistency-check result

=head1 DESCRIPTION

Show detailed information regarding a verification

=head2 Options

 required: one of test or node

 test             test request id
 node             node name, could be multiple
 block            block name, could be multiple
 kind             "cksum", "size", "dbs", or "migration"
                  default is to show any
 status           "OK", "Fail", "Queued", "Active", "Timeout", "Expired",
                  "Suspended", "Error", "Rejected" or "Indeterminate"
                  default is to show any
 test_since       show only tests after this time (*)

=head2 Output

 <node>
   <block>
     <test>
       <file/>
       ...
     </test>
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

 id              test id
 kind            type of test
 time_reported   the time when the test was done
 status          status of the test (with respect to block)
 files           number of files tested
 files_ok        number of files tested OK

=head3 <file> elements

 id              file id
 name            logical file name
 bytes           file size
 checksum        file checksum
 status          test status for this file, one of the followings:
                 "Fail", "Queued", "Active", "Timeout", "Expired",
                 "Suspended", "Error", "Rejected" or "Indeterminate"

=cut

use PHEDEX::Web::SQL;
use PHEDEX::Core::Util;
use PHEDEX::Web::Util;

# mapping format for the output
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
            file => {
                _KEY => 'F_ID',
                id => 'F_ID',
                name => 'LOGICAL_NAME',
                bytes => 'F_BYTES',
                checksum => 'CHECKSUM',
                status => 'F_STATUS'
            }
        }
    }
};

sub duration{ return 60 * 60; }
sub invoke { return blocktestfiles(@_); }
sub blocktestfiles
{
    my ($core,%h) = @_;
    my %p;
    eval
    {
        %p = &validate_params(\%h,
                uc_keys => 1,
                allow => [ qw/ node block kind status test_since test / ],
                require_one_of => [ qw/ test block / ],
                spec =>
                {
                    test => { using => 'pos_int', multiple => 1 },
                    node => { using => 'node', multiple => 1 },
                    block => { using => 'block_*', multiple => 1 },
                    kind => { regex => qr/^cksum$|^size$|^dbs$|^migration$/, multiple => 1 },
                    status => { regex => qr/^OK$|^Fail$|^Queued$|^Active$|^Timeout$|^Expired$|^Suspended$|^Error$/, multiple => 1 },
                    test_since => { using => 'time' },
                 }
        );
    };
    if ($@)
    {
        return PHEDEX::Web::Util::http_error(400,$@);
    }

    # if there is no argument, set default test_since to 24 hours ago
    if (scalar keys %p == 0)
    {
        $p{TEST_SINCE} = time() - 3600*24;
    }

    $p{'#DETAILED#'} = 1;

    return { node => PHEDEX::Core::Util::flat2tree($map, PHEDEX::Web::SQL::getBlockTestFiles($core,%p)) };
}

1;
