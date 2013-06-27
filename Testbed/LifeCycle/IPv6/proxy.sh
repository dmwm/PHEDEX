#!/bin/bash

. /data/ipv6/env.sh
voms-proxy-info --actimeleft
voms-proxy-init --voms ipv6.hepix.org --valid 24:00 \
		--cert ~/.globus/usercert.pem --key ~/.globus/userkey.pem.nok
voms-proxy-info --actimeleft
