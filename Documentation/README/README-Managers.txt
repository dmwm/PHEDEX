* Using Manager scripts

The manager scripts are for basic TMDB management functions: managing
the nodes and their topology.  The scripts are:

  - NodeManager: Add and remove nodes and node neighbour links.

* Typical tasks:

** Add a new node

To add a new neighbour B to an existing node A:

  ./NodeManager add-node			\
      -name B					\
      -host b-host.some.internet.address	\
      -cat http://cat-contact-string		\
      -neighbours A				\
      -db theDBTNSname				\
      -user DBusername				\
      -password DBpassword

To make the new node neighbour of multiple nodes, separate the node
names with commas, like this: "-neighbours A,X,Y,Z".

**  Remove a node

To remove the node B we just created:

  ./NodeManager remove-node			\
      -name B					\
      -db theDBTNSname				\
      -user DBusername				\
      -password DBpassword

** Breaking a link with new node

The previous tasks were trivial cases.  More complicated cases need
more commands.  If you want to for example break an existing network
link A-B and insert node C in between to create A-C-B, you run the
following commands, first remove the existing link and then create the
new node:

  ./NodeManager remove-link			\
      -name B					\
      -neighbours A				\
      -db theDBTNSname				\
      -user DBusername				\
      -password DBpassword

  ./NodeManager add-node			\
	-name C					\
	-host c-host.some.internet.address	\
	-cat http://cat-contact-string		\
	-neighbours A,B				\
	-db theDBTNSname			\
	-user DBusername			\
	-password DBpassword

** Removing an intermediate node

To do the exact opposite of the previous example, i.e. remove an
intermediate node C in link A-C-B, a more complex job is required.
First you need to remove the links for C and recreate direct link
between A and B.  When the transfers on the links through C have been
drained, and all data for the node C has been removed from the
database, you can proceed to delete the node C.

  ./NodeManager remove-link			\
      -name C					\
      -neighbours A,B				\
      -db theDBTNSname				\
      -user DBusername				\
      -password DBpassword

  ./NodeManager new-neighbours			\
      -name B					\
      -neighbours A				\
      -db theDBTNSname				\
      -user DBusername				\
      -password DBpassword
