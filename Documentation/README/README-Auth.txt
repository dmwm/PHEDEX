* Role authentication in PhEDEx

** Introduction

This document describes the authentication model used with the V2.2
and later PhEDEx databases.  The overview is as follows:
  - Every site will have unique passwords
  - The cms_transfermgmt account is only for admins
  - The cms_transfermgmt_reader is for read-only access only
  - The cms_transfermgmt_writer account is used for all updates,
    including agents running at the sites.

The *_writer account has no write access to the database as such.  To
gain write access, you need to acquire a "role" that gives you write
permissions to some of the tables.  Each site has a role in each of
the databases we use, and a unique password to go with it.

The sites need to keep the passwords secret: do not commit files with
the passwords into CVS, make available on the web, and so on.  If you
lose your password or accidentally make it public, please let the
admins know, and your role will be regenerated.  This will not affect
other sites.

A typical session would look like this:
  $ sqlplus `Utilities/OracleConnectId -db DBParam:Dev/CERN`
  SQL> set role site_cern identified by secret_password;
  SQL> -- you can make changes now

The agents support this notion; the information is stored in a database
parameter file, typically kept in Schema/DBParam.  The agents are given
option "-db FILE:SECTION", where FILE is a name of the file with the
database access details, and SECTION picks a specific part of it; see
below for an example.  The actual section is sent to you when you apply
for an authentication role as described below.
   Section                 Production/CERN
   Interface               Oracle
   Database                cms_transfermgmt
   AuthDBUsername          cms_transfermgmt_writer
   AuthDBPassword          FILL_ME_IN
   AuthRole                phedex_cern_prod
   AuthRolePassword        FILL_ME_IN
   ConnectionLife          86400
   LogConnection           on
   LogSQL                  off


** User's process for registering for a role

Please send the following information to cms-phedex-admins@cern.ch:

   - Site name: the name of your directory under "Custom", and the
     name used in node names after T<N>_, e.g. "CERN".  See
     README-Transfer.txt for applying a site.
   - The names of the PhEDEx nodes part of this site.
   - The e-mail address of the contact person for the site.
   - The DN for that person's grid certificate.
   - The public key portion of the grid certificate:  this is
     most likely ~/.globus/usercert.pem.  Send us the whole file.

Download a copy of PHEDEX/Schema/DBParam.Site to your site, and copy
it *OUT OF THE CVS TREE!* Only modify the copy of DBParam, we would
like to ensure that no passwords get committed into CVS.  As this
file contains plaintext password information, it should be treated
with similar care to your grid certificate files.

Wait to receive an encrypted file that contains the information you
need to access the TMDB.  To decrypt the file you'll need to use
openssl with your public key "usercert.pem" and private key
"userkey.pem" files.

   openssl smime -decrypt			 \
	   -in <the encrypted file you received> \
	   -recip ~/.globus/usercert.pem         \
	   -inkey ~/.globus/userkey.pem

It will ask you for your password, which your usual grid password that
protects access to your certificate, and then writes the decrypted info
to the standard output.  Copy and paste the output into your copied
DBParam file.

Finally, pass the location of this copied DBParam file to your agents.
They should now be able to access the TMDB.


** Admin's process for registering a role

Receive an e-mail containing the information in step 1 above.  Login
as "phedex" to "cmsgate.cern.ch", and enter the role into each
database instance.  The following instructions will register the role
for all three databases.

In the instructions "e@mail" is the person's e-mail address,
and "site" is the site name in all lowercase and "node" the
comma-separated list of PhEDEx node names belonging to the site.

   source /data/V2Nodes/sw/slc*/cms/PHEDEX/PHEDEX_*/etc/profile.d/env.sh

   cd ~/private/roles/V2
   cat > ../Keys/EMAIL (paste in the usercert.pem)
   Schema/OracleInitRole.sh DBParam:Production ../Keys/e@mail site node
   /usr/sbin/sendmail -t < Output/phedex_site_prod:e@mail

   cd ~/private/roles/Dev
   Schema/OracleInitRole.sh DBParam:Dev ../Keys/e@mail site node
   /usr/sbin/sendmail -t < Output/phedex_site_dev:e@mail

   cd ~/private/roles/SC4
   Schema/OracleInitRole.sh DBParam:SC4 Keys/e@mail site node
   /usr/sbin/sendmail -t < Output/phedex_site_sc4:e@mail

A rough example of the above commands:

   scp lat@lxplus:~/.globus/usercert.pem ~/private/roles/Keys/lassi.tuura@cern.ch
   Schema/OracleInitRole.sh DBParam:SC4 ../Keys/lassi.tuura@cern.ch \
     cern T1_CERN_MSS,T1_CERN_Buffer,T0_CERN_Export,T0_CERN_MSS
   /usr/sbin/sendmail -t < Output/phedex_cern_sc4:lassi.tuura@cern.ch
