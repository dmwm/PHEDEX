package PHEDEX::File::Download::Circuits::TFCUtils;

use strict;
use warnings;
use base 'Exporter';

our @EXPORT = qw(checkPort determineAddressType replaceHostname
                 ADDRESS_INVALID ADDRESS_IPv4 ADDRESS_IPv6 ADDRESS_HOSTNAME
                 PORT_VALID PORT_INVALID);

my $validIpv4AddressRegex = '(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])';
my $validIpv6AddressRegex = '\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*';
my $validHostnameRegex = '(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z])+';
my $validPortRegex= '([1-9]|[0-9]{2,4}|6[0-5]{2}[0-3][0-5])';

use constant {
    ADDRESS_INVALID         =>      -1,
    ADDRESS_IPv4            =>      1,
    ADDRESS_IPv6            =>      2,
    ADDRESS_HOSTNAME        =>      3,
    PORT_VALID              =>      11,
    PORT_INVALID            =>      -11,
};

# Determines if the specified port is in the 0-65535 range
sub checkPort {
    my ($port) = @_;
    return !defined $port ? PORT_INVALID : $port > 0 && $port < 65536 ? PORT_VALID : PORT_INVALID;
}

# Determines if the specified attribute is an IPv4 address, a valid hostname or neither
sub determineAddressType {
    my ($hostname) = @_;

    return  !defined $hostname ? ADDRESS_INVALID :
            $hostname =~ ('^'.$validIpv4AddressRegex.'$') ?
            ADDRESS_IPv4 : $hostname =~ ('^'.$validIpv6AddressRegex.'$') ?
            ADDRESS_IPv6 : $hostname =~ ('^'.$validHostnameRegex.'$') ?
            ADDRESS_HOSTNAME : ADDRESS_INVALID;
}

# Replaces the current IP or hostname in PFN with the one from the private circuit
# If it's unable to find a valid hostname/ip to replace, it will return undef
sub replaceHostname
{
    my ($pfn, $protocol, $circuit_ip, $circuit_port) = @_;

    # Don't attempt to do anything if the provided IP is invalid
    return if (
                !defined $pfn || !defined $protocol ||
                determineAddressType($circuit_ip) < 0 ||
                (defined $circuit_port && checkPort($circuit_port) < 0)
              );

    # Find the hostname or ip in the PFN
    my $pfnMatch = "^($protocol:\/\/)($validIpv4AddressRegex|$validIpv6AddressRegex|$validHostnameRegex)((:$validPortRegex)?)(\/.*)\$";
    my @matchExtract = ($pfn =~ m/$pfnMatch/);

    # Special case where IPv6 is given with a port number since it has to be matched to [ip]:port
    if (! defined $matchExtract[1]) {
        my $validIpv6AddressRegexWPort = '(\['.$validIpv6AddressRegex.'\])(:'.$validPortRegex.')'.'(\/.*)';
        $pfnMatch = "^($protocol:\/\/)$validIpv6AddressRegexWPort\$";
        @matchExtract = ($pfn =~ m/$pfnMatch/);
    }

    my ($extractedHost, $extractedPort, $extractedPath) = ($matchExtract[1], $matchExtract[@matchExtract - 2], $matchExtract[@matchExtract - 1]);

    $circuit_port = $extractedPort if (checkPort($circuit_port) == PORT_INVALID && checkPort($extractedPort));

    return if (!defined $extractedHost);

    my $newPFN = "$protocol://".
                 (determineAddressType($circuit_ip) == ADDRESS_IPv4 ||
                  determineAddressType($circuit_ip) == ADDRESS_IPv6 && checkPort($circuit_port) < 0 ? "$circuit_ip" : "[$circuit_ip]").
                 (checkPort($circuit_port) > 0 ? ":".$circuit_port : "").
                 $extractedPath;

    return $newPFN;
}


1;