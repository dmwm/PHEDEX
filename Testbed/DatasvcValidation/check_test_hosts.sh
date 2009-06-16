#!/bin/sh

# usage: check_test_host.sh <test_host_file>
#
# <test_host_file> is the file that contains the names of the test
# hosts, one per line. It is the same file read by perf_test.pl
#
# This script checks if the hosts can be successfully ssh-ed into

for i in `grep -v "#" $1`
do
	echo -n $i " " ; ssh $i echo OK 2> /dev/null
done
