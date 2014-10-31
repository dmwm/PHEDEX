This configuration sets up a T0 and a T1. Both have an _MSS, an _Disk and a
_Buffer node.

Check the 2NodeLifecycle.conf is using a data-service that supports the
database you are using. Then just run 'tbed_startup.sh' to start the agents.

To stop them, run 'tbed_stop.sh'
