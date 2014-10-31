This directory contains several example configurations for the LifeCycle agent.
Some are better maintained than others, so make sure you know what you're looking
at before you use it.

examples
========
This contains simple standalone examples that illustrate how to use the LifeCycle
agent. Use these to familiarise yourself with the power of this awesome tool!

2Node
=====
This is probably the most up-to-date set of PhEDEx examples. It sets up a 2-node
PhEDEx installation consisting of a Tier-0 and a Tier-1, each with an MSS, Buffer
and Disk endpoint.

It also has a LifeCycle configuration file that injects fake data for fake transfer.
This is useful for regression/integration testing of simple agent fixes.  

4Node
=====
Like the 2Node directory, but for 4 x T1 instead. This isn't complete on its own,
it needs stuff from the 2Node example. Read the README.txt for more details.

T012
====
Even less up-to-date than the 4Node example, this one creates a Tier-0, a Tier-1,
and 2 x Tier-2.

DBS3
====
Files used for integration testing of DBS3.

PhEDEx+DAS+DBS
==============
The configuration used for integration testing of PhEDEx, DBS3 and DAS, together.

IPv6
====
An incomplete set of the files used in the IPv6 gridftp testbed.

obsolete
========
Files from previous incarnations of the LifeCycle agent. Useful as inspiration,
but they'll never run again :-)
