package PHEDEX::Tests::File::Download::TestTFCUtils;

use strict;
use warnings;

use PHEDEX::File::Download::Circuits::TFCUtils;
use Test::More;

my ($circuitIpv4, $circuitIpv6, $port, $protocol)= ("127.0.0.1", "::1", 8080, "fdt");

sub testCheckPort {
    is(checkPort(1), PORT_VALID,        'checkPort - Valid port');
    is(checkPort(65535), PORT_VALID,    'checkPort - Valid port');
    is(checkPort(undef), PORT_INVALID,  'checkPort - Invalid port: undef');
    is(checkPort(0), PORT_INVALID,      'checkPort - Invalid port: 0');
    is(checkPort(65536), PORT_INVALID,  'checkPort - Invalid port: 65536');
}

sub testDetermineAddressType_IPv4 {
    is(determineAddressType("127.0.0.1"), ADDRESS_IPv4,                                 'determineAddressType - Valid IPv4 address - loopback');
    is(determineAddressType("127.0.0.255"), ADDRESS_IPv4,                               'determineAddressType - Valid IPv4 address');
    is(determineAddressType("127.0.0.256"), ADDRESS_INVALID,                            'determineAddressType - Invalid IPv4 address - out of range');
    is(determineAddressType("127.0.0"), ADDRESS_INVALID,                                'determineAddressType - Invalid IPv4 address - not enough fields');
    is(determineAddressType("127.0.0.255.255"), ADDRESS_INVALID,                        'determineAddressType - Invalid IPv4 address - too mane fields');
}

sub testDetermineAddressType_IPv6 {
    is(determineAddressType("2001:0DB8:AC10:FE01:0000:0000:0000:0000"), ADDRESS_IPv6,           'determineAddressType - Valid full IPv6 address - uppercase');
    is(determineAddressType("2001:0DB8:AC10:FE01::"), ADDRESS_IPv6,                             'determineAddressType - Valid short IPv6 address - uppercase');
    is(determineAddressType("2001:0db8:ac10:fe01::"), ADDRESS_IPv6,                             'determineAddressType - Valid short IPv6 address - lowercase');
    is(determineAddressType("2001:0DB8:AC10:FE01:0000:0000:0000"), ADDRESS_INVALID,             'determineAddressType - Invalid IPv6 address - not enough fields');
    is(determineAddressType("2001:0DB8:AC10:FE01:0000:0000:0000:0000:0000"), ADDRESS_INVALID,   'determineAddressType - Invalid IPv6 address - too many fields');
    is(determineAddressType("2001:0DB8:AC10::FE01::"), ADDRESS_INVALID,                         'determineAddressType - Invalid IPv6 address - shorthand used two times');
}

sub testDetermineAddressType_Hostname{
    is(determineAddressType("292.168.0.a1a"), ADDRESS_HOSTNAME,                         'determineAddressType - Valid hostname');
    is(determineAddressType("fdt.cern.ch"), ADDRESS_HOSTNAME,                           'determineAddressType - Valid hostname');
    is(determineAddressType("-fdt.cern.ch"), ADDRESS_INVALID,                           'determineAddressType - Invalid hostname');
    is(determineAddressType("fdt.cern.ch/321"), ADDRESS_INVALID,                        'determineAddressType - Invalid hostname');
}

sub testReplaceHostname_Initial_parameters {
    is(replaceHostname(undef, $protocol, $circuitIpv4, $port), undef,                                                                   'replaceHostname - Undefined PFN');
    is(replaceHostname("fdt://vlad.cern.ch/data/foo.root", $protocol, undef, $port), undef,                                             'replaceHostname - Undefined circuit IP');
    is(replaceHostname("fdt://vlad.cern.ch/data/foo.root", undef, $circuitIpv4, $port), undef,                                          'replaceHostname - Undefined protocol');
}

sub testReplaceHostname_Changes_to_PFNs {
    my ($host) = @_;

    is(replaceHostname("fdt://".$host."/data/foo.root", $protocol, $circuitIpv4), "fdt://127.0.0.1/data/foo.root",                   "replaceHostname - $host changed with 127.0.0.1");
    is(replaceHostname("fdt://".$host."/data/foo.root", $protocol, $circuitIpv6), "fdt://::1/data/foo.root",                         "replaceHostname - $host changed with ::1");
    is(replaceHostname("fdt://".$host."/data/foo.root", $protocol, $circuitIpv4, $port), "fdt://127.0.0.1:8080/data/foo.root",       "replaceHostname - $host changed with 127.0.0.1:8080");
    is(replaceHostname("fdt://".$host."/data/foo.root", $protocol, $circuitIpv6, $port), "fdt://[::1]:8080/data/foo.root",           "replaceHostname - $host changed with [::1]:8080");
    if (determineAddressType($host) == ADDRESS_IPv6) {
        is(replaceHostname("fdt://[".$host."]:80/data/foo.root", $protocol, $circuitIpv4, $port), "fdt://127.0.0.1:8080/data/foo.root",    "replaceHostname - [$host]:80 changed with 127.0.0.1:8080");
        is(replaceHostname("fdt://[".$host."]:80/data/foo.root", $protocol, $circuitIpv6, $port), "fdt://[::1]:8080/data/foo.root",        "replaceHostname - [$host]:80 changed with [::1]:8080");
    } else {
        is(replaceHostname("fdt://".$host.":80/data/foo.root", $protocol, $circuitIpv4, $port), "fdt://127.0.0.1:8080/data/foo.root",    "replaceHostname - $host:80 changed with 127.0.0.1:8080");
        is(replaceHostname("fdt://".$host.":80/data/foo.root", $protocol, $circuitIpv6, $port), "fdt://[::1]:8080/data/foo.root",        "replaceHostname - $host:80 changed with [::1]:8080");
    }

}

sub testReplaceHostname_Hostname_IP_scanning {
    is(replaceHostname("fdt://-vlad.cern.ch/data/foo.root", $protocol, $circuitIpv4, 80), undef,                            "replaceHostname - Cannot match host");
    is(replaceHostname("fdt://127.0.0.256/data/foo.root", $protocol, $circuitIpv4, 80), undef,                              "replaceHostname - Cannot match IP");
    is(replaceHostname("fdt://2001:0DB8:AC10::FE01::/data/foo.root", $protocol, $circuitIpv4, 80), undef,                   "replaceHostname - Cannot match IP");
    is(replaceHostname("fdt://::1:80/data/foo.root", $protocol, $circuitIpv4), "fdt://127.0.0.1/data/foo.root",             "replaceHostname - ::1:80 replaced with 127.0.0.1");
    is(replaceHostname("fdt://[::1]:80/data/foo.root", $protocol, $circuitIpv4, 8080), "fdt://127.0.0.1:8080/data/foo.root","replaceHostname - [::1]:80 replaced with 127.0.0.1:80");
}

#######

testCheckPort();

testDetermineAddressType_IPv4();
testDetermineAddressType_IPv6();
testDetermineAddressType_Hostname();

testReplaceHostname_Initial_parameters();
testReplaceHostname_Changes_to_PFNs("vlad.cern.ch");
testReplaceHostname_Changes_to_PFNs("192.168.0.1");
testReplaceHostname_Changes_to_PFNs("2001:0DB8:AC10:FE01::");

testReplaceHostname_Hostname_IP_scanning();

# Real data test
is(replaceHostname("fdt://vlad-vm-slc6.cern.ch:8444/data/ANSE/store/data/circuit/data/RAW/000/000000000/afebahdtsl-53b3c5a0.root", $protocol, "137.138.42.16", 8444), "fdt://137.138.42.16:8444/data/ANSE/store/data/circuit/data/RAW/000/000000000/afebahdtsl-53b3c5a0.root", "replaced correctly in PFN");
is(replaceHostname("fdt://vlad-vm-slc6.cern.ch:8444/data/ANSE/store/data/circuit/data/RAW/000/000000000/afebahdtsl-53b3c5a0.root", $protocol, "137.138.42.16"), "fdt://137.138.42.16:8444/data/ANSE/store/data/circuit/data/RAW/000/000000000/afebahdtsl-53b3c5a0.root", "replaced correctly in PFN");

done_testing();

1;
