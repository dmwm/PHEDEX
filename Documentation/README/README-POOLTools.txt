This README focuses on the usage of the so called "FC tools", which are
distributed with POOL.  PhEDEx needs them in order to perform updates to
the local MySQL POOL catalogues hosted at each participating site.  The
installation of these tools is performed by the InstallPOOL script, which
is part of the PhEDEx deployment suite.

The most common use-case is the query for PFNs or LFNs using GUIDs.  Hence
FClistLFN will be used as example.  FClistPFN works exactly the same.  For
all other FC commands, please refer to the POOL manual.

The FC commands typically need one argument, namely the contact string for
the catalogue to use. Currently three diferent catalogue types are supported:
  1. XML file base catalogues
  2. MySQL DB based catalogues
  3. Oracle based catalogues.

In order to contact an XML file based catalogue, the following syntax is
required:
  FClistLFN -u xmlcatalog_file:<Path_to_XML_file>

Contacting a MySQL based catalogue is also quite easy and works nearly the
same:
  FClistLFN -u mysqlcatalog_mysql://<username>:<password>@<machine>/<db-name>

In order to contact an Oracle based catalogue some additional steps have
to be performed. First you have to make sure, that your LD_LIBRARY_PATH
contains the Oracle libs. If you sourced the environment scripts created
during the PhEDEx deployment, this step is automatically covered.

In addition you need to define username and password via evironment variables
(sh example below):
  export POOL_AUTH_USER=<username>
  export POOL_AUTH_PASSWORD=<password>

The syntax for contacting to the Oracle catalogue is the following:
  FClistLFN -u relationalcatalog_oracle://DBname/User
