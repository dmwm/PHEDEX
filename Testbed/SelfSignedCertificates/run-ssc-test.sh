#!/bin/bash

# IMPORTANT: 
# Please read the following twiki before
# https://twiki.cern.ch/twiki/bin/viewauth/CMS/DataserviceTestsLifecycle#Script_for_automatized_tests_sel

# Define Roles for check by the cert file
testcerts=( cert-Admin.pem cert-Data_T1_Test1.pem cert-Data_T0.pem )

# Check following nodes for injecting data
testinject=( T0_Test_Buffer T1_Test1_Buffer )

# Check following nodes for subscribing data
testsubscribe=( T1_Test1_MSS T1_Test2_MSS )

#Not yet in place: Define known outcome of test
testresults=( 1 0 )

ELEMENTS=${#testcerts[@]}
ELEMENTS_SUB=${#testsubscribe[@]}
ELEMENTS_INJ=${#testinject[@]}

# Define the ADMIN certs
export myAuth_cert_A=cert-Admin.pem
export myAuth_key_A=key-Admin.pem

echo "Test Lifecycle: " > results.txt
echo "-------------------" >> results.txt

#Part 1: Test Inject
echo "Test Inject" >> results.txt
for (( i=0;i<$ELEMENTS;i++)); do
    export myAuth_cert=${testcerts[${i}]}
    export myAuth_key=key${myAuth_cert/cert}
    export myAuth_cert_B=${testcerts[${i}]}
    export myAuth_key_B=key${myAuth_cert/cert}
    export expresult=${testresults[${i}]}
    for (( j=0;j<$ELEMENTS_INJ;j++)); do
	export inject=${testinject[${j}]}
	perl Lifecycle.pl --config=self4NodeInject.conf > /dev/null 2> /dev/null
	lcerror=$?
	if [ $lcerror == 100 ]; then echo ${myAuth_cert_B} ${inject} fail >> results.txt ; fi;
	if [ $lcerror == 123 ]; then echo ${myAuth_cert_B} ${inject} success >> results.txt; fi;
    done
done
echo "-------------------">> results.txt
echo "Test Subscribe">> results.txt

#Part 2: Test Subscribe
for (( i=0;i<$ELEMENTS;i++)); do
    export myAuth_cert=${testcerts[${i}]}
    export myAuth_key=key${myAuth_cert/cert}
    export myAuth_cert_B=${testcerts[${i}]}
    export myAuth_key_B=key${myAuth_cert/cert}
    for (( j=0;j<$ELEMENTS_SUB;j++)); do
	export subscribenode=${testsubscribe[${j}]}
	perl Lifecycle.pl --config=self4NodeSubscribe.conf > /dev/null 2> /dev/null
	lcerror=$?
	if [ $lcerror == 100 ]; then echo ${myAuth_cert_B} ${subscribenode} fail >> results.txt ; fi;
	if [ $lcerror == 123 ]; then echo ${myAuth_cert_B} ${subscribenode} success >> results.txt; fi;
    done
done

