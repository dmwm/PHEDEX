from ds import dsunittest
import kenosis

import re
import sha

kenosisDomainString = "(0x)?([\w\.]+)\.(node\.)?(\w+)\.kenosisp2p\.org"
kenosisDomainRe = re.compile(kenosisDomainString)
kenosisUrlRe = re.compile("\w+://" + kenosisDomainString)

#def domainName(serviceName):
#    return "%s.kenosisp2p.org" % serviceName

def hostNameFor(nodeAddress, serviceName):
    assert kenosis.isNodeAddress(nodeAddress=nodeAddress)
    if nodeAddress.startswith("0x"):
        nodeAddress = nodeAddress.replace("0x", "", 1)
    host = "%s.node.%s.kenosisp2p.org" % (nodeAddress, serviceName)
    dsunittest.assertEqual(
        ("0x" + nodeAddress, serviceName), nodeAddressAndServiceNameFrom(domain=host))
    return host

def nodeAddressAndServiceNameFrom(url=None, domain=None):
    assert url or domain
    assert not (url and domain)

    if domain:
        m = kenosisDomainRe.match(domain)
    else:
        m = kenosisUrlRe.match(url)
    if m:
        data = m.group(2)
        service = m.group(4)
        isnode = bool(m.group(3))
        if isnode:
            return "0x" + data, service
        else:
            return "0x" + sha.sha(data).hexdigest(), service
    else:
        return None, None


