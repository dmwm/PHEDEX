zone = [
    SOA(
        # For whom we are the authority
        'kenosisp2p.org',

        # This nameserver's name
        mname = "ns1.redheron.com",

        # Mailbox of individual who handles this
        rname = "org.kenosisp2p.ns1.redheron.com",

        # Unique serial identifying this SOA data
        serial = 2004121117,

        # Time interval before zone should be refreshed
        refresh = "1H",

        # Interval before failed refresh should be retried
        retry = "1H",

        # Upper limit on time interval before expiry
        expire = "1H",

        # Minimum TTL
        minimum = "1H"
    ),

    A('ns1.kenosisp2p.org', '67.164.12.28'),
    A("root.kenosisp2p.org", "67.164.12.28"),

    #NS('kenosisp2p.org', "ns1.redheron.com"),
    #NS('kenosisp2p.org', "ns2.redheron.com"),
    #NS('bt.kenosisp2p.org', "ns1.kenosisp2p.org"),

    A('kenosisp2p.org', '66.35.250.210'),
    CNAME("www.kenosisp2p.org", "vhost.sourceforge.net"),
    CNAME("cvs.kenosisp2p.org", "cvs.sourceforge.net")

]   
